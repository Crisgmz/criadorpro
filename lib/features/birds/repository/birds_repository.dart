import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/birds_dao.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/domain/bird_traits.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure.dart';
import '../../../core/media/photo_subject.dart';
import '../../../core/media/photo_sync.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/remote_merge.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../model/bird.dart';

/// Acceso a ejemplares. Escribe siempre primero en Drift y encola el cambio;
/// nunca espera a la red para dar por buena una operación.
class BirdsRepository implements RemotePuller, PhotoSubject {
  BirdsRepository({
    required AppDatabase database,
    required BirdsDao birdsDao,
    required ProfilesDao profilesDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _birdsDao = birdsDao,
       _profilesDao = profilesDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _uuid = uuid,
       _clock = clock;

  final AppDatabase _database;
  final BirdsDao _birdsDao;
  final ProfilesDao _profilesDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  String get table => 'birds';

  Stream<List<Bird>> watchBirds({
    required String ownerId,
    String? search,
    Sex? sex,
    BirdStatus? status,
  }) => _birdsDao
      .watchAll(ownerId: ownerId, search: search, sex: sex?.id, status: status?.id)
      .map((rows) => rows.map(Bird.fromRow).toList());

  Stream<Bird?> watchBird(String id) =>
      _birdsDao.watchById(id).map((row) => row == null ? null : Bird.fromRow(row));

  Stream<int> watchCount(String ownerId) => _birdsDao.watchCountForOwner(ownerId);

  /// Opciones de color de plumaje o de cresta, con su número de ejemplares.
  ///
  /// La lista es **abierta**: lo que el criadero ya usa, más las sugerencias de
  /// fábrica que aún no ha tocado.
  Stream<List<TraitOption>> watchTraitOptions({
    required String ownerId,
    required BirdTrait trait,
  }) => _birdsDao
      .watchTraitUsage(ownerId: ownerId, isComb: trait == BirdTrait.comb)
      .map((usage) => buildTraitOptions(trait: trait, inUse: usage));

  /// Descendencia directa de un ejemplar — `RF-REG-13`.
  Stream<List<Bird>> watchChildren(String parentId) =>
      _birdsDao.watchChildren(parentId).map((rows) => rows.map(Bird.fromRow).toList());

  Stream<Map<Sex, int>> watchSexTally(String ownerId) => _birdsDao
      .watchSexTally(ownerId)
      .map((tally) => {for (final entry in tally.entries) Sex.fromId(entry.key): entry.value});

  Future<Result<Bird>> findById(String id) => guard(
    () async {
      final row = await _birdsDao.findById(id);
      if (row == null) throw const _NotFound();
      return Bird.fromRow(row);
    },
    (error, stackTrace) => error is _NotFound
        ? const NotFoundFailure(debugMessage: 'bird no encontrado')
        : DatabaseFailure(debugMessage: error.toString(), cause: error),
  );

  /// Posibles progenitores para el selector del formulario.
  Future<Result<List<Bird>>> parentCandidates({
    required String ownerId,
    required Sex sex,
    String? excludeId,
    String? search,
  }) => guard(() async {
    final rows = await _birdsDao.parentCandidates(
      ownerId: ownerId,
      sex: sex.id,
      excludeId: excludeId,
      search: search,
    );
    return rows.map(Bird.fromRow).toList();
  }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));

  /// Placa que se propondrá en el próximo alta — `RS-01`.
  ///
  /// Sale del perfil, que es donde vive el contador. Sin perfil todavía (primer
  /// arranque sin sincronizar) se arranca en 1.
  Future<int> nextPlate(String ownerId) async {
    final profile = await _profilesDao.findById(ownerId);
    return profile?.nextPlate ?? 1;
  }

  /// `true` si ese criadero ya tiene un ejemplar con esa placa.
  ///
  /// `RV-08` la trata como advertencia, no como bloqueo: duplicar una placa es
  /// casi siempre un error, pero a veces el libro de papel la repite y el
  /// criador necesita reflejarlo tal cual.
  Future<bool> isPlateTaken({required String ownerId, required int plate, String? excludeId}) =>
      _birdsDao.existsWithPlate(ownerId: ownerId, plate: plate, excludeId: excludeId);

  /// Crea o actualiza un ejemplar.
  ///
  /// Aquí — y no en la UI — se aplica el límite de ejemplares del plan, para
  /// que ninguna otra vía de alta lo pueda saltar (`RS-02`).
  Future<Result<Bird>> save(Bird draft) async {
    if (draft.plate < 1) {
      return const Err(ValidationFailure('plate', debugMessage: 'placa obligatoria'));
    }

    if (draft.isNew) {
      final limitFailure = await _checkPlanLimit(draft.ownerId);
      if (limitFailure != null) return Err(limitFailure);
    }

    final now = _clock();
    final name = draft.name?.trim();

    // Si la foto local cambió, la URL que había describe a la anterior. Se
    // suelta para que la sincronización de fotos la vuelva a subir: dejarla
    // puesta haría que el ejemplar se quedara para siempre con la foto vieja
    // en los demás dispositivos, sin que nada fallara aquí (`RF-REG-15`).
    final stored = draft.isNew ? null : await _birdsDao.findById(draft.id);
    final photoChanged = stored != null && stored.photoPath != draft.photoPath;

    final bird = draft.copyWith(
      id: draft.isNew ? _uuid.v4() : draft.id,
      // El nombre es opcional: en blanco se guarda como nulo para no tener que
      // distinguir «sin nombre» de «nombre vacío» en cada consulta.
      name: () => (name == null || name.isEmpty) ? null : name,
      photoUrl: photoChanged ? () => null : null,
      updatedAt: now,
    );

    return guard(() async {
      await _database.transaction(() async {
        await _birdsDao.upsert(bird.toCompanion(dirty: true));
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: bird.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(bird.toRemoteJson()),
          now: now,
        );
        // El contador solo avanza en altas: editar un ejemplar no consume placa.
        if (draft.isNew) {
          await _profilesDao.bumpNextPlate(ownerId: bird.ownerId, atLeast: bird.plate + 1);
        }
      });
      return bird;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  @override
  String get bucket => PhotoSyncService.birdBucket;

  @override
  Future<List<PendingPhoto>> pendingUploads(String ownerId) async => [
    for (final row in await _birdsDao.photosPendingUpload(ownerId))
      PendingPhoto(id: row.id, localPath: row.photoPath),
  ];

  @override
  Future<List<PendingPhoto>> pendingDownloads(String ownerId) async => [
    for (final row in await _birdsDao.photosPendingDownload(ownerId))
      PendingPhoto(id: row.id, objectPath: row.photoUrl),
  ];

  @override
  Future<void> setPhotoPath(String id, String? path) => _birdsDao.setPhotoPath(id, path);

  /// `RF-REG-15` — anota la foto ya subida a Storage.
  ///
  /// La escritura va con su entrada en la cola, como cualquier otra: es la URL
  /// lo que hace que la foto aparezca en el otro teléfono del criadero, y sin
  /// encolarla se quedaría en este.
  ///
  /// No toca `updated_at`: la foto no es un cambio que el criador hizo, y
  /// moverlo haría que esta fila ganara la resolución de conflictos (`RS-09`)
  /// contra una edición real hecha en otro dispositivo mientras tanto.
  @override
  Future<void> setPhotoUrl({required String id, required String objectPath}) async {
    final existing = await _birdsDao.findById(id);
    if (existing == null) return;

    final bird = Bird.fromRow(existing).copyWith(photoUrl: () => objectPath);

    await _database.transaction(() async {
      await _birdsDao.upsert(bird.toCompanion(dirty: true));
      await _syncQueue.enqueue(
        entityTable: table,
        entityId: bird.id,
        operation: SyncOperation.upsert,
        payload: jsonEncode(bird.toRemoteJson()),
        now: bird.updatedAt,
      );
    });
  }

  /// Borrado lógico: desaparece de las listas pero viaja al resto de
  /// dispositivos como baja, en vez de "reaparecer" en la siguiente bajada.
  Future<Result<void>> delete(String id) async {
    final existing = await _birdsDao.findById(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'bird no encontrado'));
    }

    final now = _clock();
    final deleted = Bird.fromRow(existing).copyWith(updatedAt: now, isDeleted: true);

    return guard(() async {
      await _database.transaction(() async {
        await _birdsDao.softDelete(id, now);
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted.toRemoteJson()),
          now: now,
        );
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// `null` si cabe uno más. El plan se lee del perfil local; si todavía no se
  /// ha sincronizado se asume Free, que es lo más restrictivo.
  Future<PlanLimitFailure?> _checkPlanLimit(String ownerId) async {
    final profile = await _profilesDao.findById(ownerId);
    final plan = SubscriptionPlan.fromId(profile?.plan);
    final limit = plan.birdLimit;
    if (limit == null) return null;

    final current = await _birdsDao.countForOwner(ownerId);
    if (current < limit) return null;
    return PlanLimitFailure(limit: limit, current: current);
  }

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    final query = _supabase.client.from(table).select().eq('owner_id', ownerId);
    final rows = since == null
        ? await query
        : await query.gt('updated_at', since.toUtc().toIso8601String());

    if (rows.isEmpty) return null;

    // `RS-09`: gana el `updated_at` más reciente y, en empate, el servidor. La
    // marca de agua avanza igual con las filas que gana lo local — ver
    // `RemoteMerge`, que explica por qué eso no las pierde.
    final merge = await RemoteMerge.forTable(_syncQueue, table);

    DateTime? latest;
    final incoming = <BirdsCompanion>[];
    for (final row in rows) {
      final bird = Bird.fromRemoteJson(row);
      if (latest == null || bird.updatedAt.isAfter(latest)) latest = bird.updatedAt;
      if (!await merge.accepts(bird.id, bird.updatedAt)) continue;
      incoming.add(bird.toCompanion());
    }

    if (incoming.isNotEmpty) await _birdsDao.upsertAll(incoming);
    return latest;
  }
}

/// Señal interna para distinguir "no existe" de un error real de SQLite.
class _NotFound implements Exception {
  const _NotFound();
}
