import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/birds_dao.dart';
import '../../../core/db/daos/clutches_dao.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/remote_merge.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../model/bird.dart';
import '../model/clutch.dart';

/// Registro de camadas — `RF-REG-08` a `RF-REG-10`.
///
/// Es la función que justifica el producto: ocho crías registradas en menos de
/// un minuto, contra los ocho renglones que el criador escribiría a mano.
class ClutchesRepository implements RemotePuller {
  ClutchesRepository({
    required AppDatabase database,
    required ClutchesDao clutchesDao,
    required BirdsDao birdsDao,
    required ProfilesDao profilesDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _clutchesDao = clutchesDao,
       _birdsDao = birdsDao,
       _profilesDao = profilesDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _uuid = uuid,
       _clock = clock;

  final AppDatabase _database;
  final ClutchesDao _clutchesDao;
  final BirdsDao _birdsDao;
  final ProfilesDao _profilesDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Crías por camada — `RV-11`.
  static const int minHatched = 1;
  static const int maxHatched = 30;

  /// Huevos por puesta (SRS §4).
  static const int maxEggs = 30;

  @override
  String get table => 'clutches';

  Stream<List<Clutch>> watchClutches(String ownerId) =>
      _clutchesDao.watchAll(ownerId).map((rows) => rows.map(Clutch.fromRow).toList());

  Stream<int> watchCount(String ownerId) => _clutchesDao.watchCountForOwner(ownerId);

  /// Camadas concretas por id, para agrupar la descendencia de una ficha.
  Future<Map<String, Clutch>> findByIds(Iterable<String> ids) async {
    final result = <String, Clutch>{};
    for (final id in ids.toSet()) {
      final row = await _clutchesDao.findById(id);
      if (row != null) result[id] = Clutch.fromRow(row);
    }
    return result;
  }

  /// Placa con la que arrancaría la camada. Solo para mostrarla en el
  /// formulario: la reserva de verdad ocurre dentro de la transacción.
  Future<int> nextPlate(String ownerId) async {
    final profile = await _profilesDao.findById(ownerId);
    return profile?.nextPlate ?? 1;
  }

  /// Registra la camada y sus crías **en una sola transacción local**.
  ///
  /// `RS-04` es tajante: o se crea todo —camada, las N crías y el avance del
  /// contador de placas— o no se crea nada. Un fallo a mitad no puede dejar
  /// tres crías registradas y el contador movido, porque el criador no tendría
  /// forma de saber qué quedó a medias.
  Future<Result<ClutchRegistration>> register({
    required String ownerId,
    required DateTime date,
    required int hatched,
    int? eggs,
    String? fatherId,
    String? motherId,
    String? line,
    String? notes,
    CrossStatus crossStatus = CrossStatus.done,
    String? birthMark,
    String? wingBandLeft,
    String? wingBandRight,
  }) async {
    final validation = await _validate(
      ownerId: ownerId,
      date: date,
      hatched: hatched,
      eggs: eggs,
      fatherId: fatherId,
      motherId: motherId,
    );
    if (validation != null) return Err(validation);

    final now = _clock();

    return guard(() async {
      late ClutchRegistration registration;

      await _database.transaction(() async {
        // Dentro de la transacción: si una cría falla, la reserva se deshace
        // con ella y la placa no se pierde.
        final firstPlate = await _profilesDao.reservePlateBlock(ownerId: ownerId, count: hatched);

        final clutch = Clutch(
          id: _uuid.v4(),
          ownerId: ownerId,
          fatherId: fatherId,
          motherId: motherId,
          date: date,
          eggs: eggs,
          hatched: hatched,
          notes: _trimToNull(notes),
          crossStatus: crossStatus,
          birthMark: birthMark,
          wingBandLeft: wingBandLeft,
          wingBandRight: wingBandRight,
          createdAt: now,
          updatedAt: now,
        );

        // La camada primero: la cola es FIFO estricta y las crías la
        // referencian, así que tiene que subir antes que ellas.
        await _clutchesDao.upsert(clutch.toCompanion(dirty: true));
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: clutch.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(clutch.toRemoteJson()),
          now: now,
        );

        final chicks = <Bird>[];
        for (var i = 0; i < hatched; i++) {
          // Sexo sin definir: a un pollito recién nacido no se le determina, y
          // obligar a elegirlo aquí destruiría el minuto que promete la
          // pantalla. Se corrige después desde la ficha.
          final chick = Bird(
            id: _uuid.v4(),
            ownerId: ownerId,
            plate: firstPlate + i,
            sex: Sex.unknown,
            status: BirdStatus.active,
            birthDate: date,
            line: _trimToNull(line),
            // La marca y las cintas se capturan una vez para toda la camada y
            // **cada cría nace con ellas**: las de un mismo cruce se marcan
            // igual, y pedirlo quince veces es lo que hace que no se marque
            // ninguna. Cada una puede corregirlas luego en su ficha.
            birthMark: birthMark,
            wingBandLeft: wingBandLeft,
            wingBandRight: wingBandRight,
            fatherId: fatherId,
            motherId: motherId,
            clutchId: clutch.id,
            createdAt: now,
            updatedAt: now,
          );

          await _birdsDao.upsert(chick.toCompanion(dirty: true));
          await _syncQueue.enqueue(
            entityTable: 'birds',
            entityId: chick.id,
            operation: SyncOperation.upsert,
            payload: jsonEncode(chick.toRemoteJson()),
            now: now,
          );
          chicks.add(chick);
        }

        registration = ClutchRegistration(clutch: clutch, chicks: chicks);
      });

      return registration;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Borrado lógico de la camada. **No borra las crías**: ya son ejemplares del
  /// criadero por derecho propio, y perderlos por deshacer el registro del
  /// cruce sería destruir datos que el criador no pidió destruir (`RS-10`).
  Future<Result<void>> delete(String id) async {
    final existing = await _clutchesDao.findById(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'clutch no encontrado'));
    }

    final now = _clock();
    final deleted = Clutch.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    return guard(() async {
      await _database.transaction(() async {
        await _clutchesDao.softDelete(id, now);
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted),
          now: now,
        );
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Reglas de datos, todas aquí y no en la UI: una camada también puede
  /// entrar por importación o por sincronización, y ninguna vía puede saltarse
  /// estas comprobaciones.
  Future<Failure?> _validate({
    required String ownerId,
    required DateTime date,
    required int hatched,
    required int? eggs,
    required String? fatherId,
    required String? motherId,
  }) async {
    // `RV-11`: de 1 a 30 crías.
    if (hatched < minHatched || hatched > maxHatched) {
      return const ValidationFailure('hatched', debugMessage: 'crías fuera de 1..30');
    }

    if (eggs != null) {
      if (eggs < 0 || eggs > maxEggs) {
        return const ValidationFailure('eggs', debugMessage: 'huevos fuera de 0..30');
      }
      // No pueden nacer más crías que huevos puestos.
      if (hatched > eggs) {
        return const ValidationFailure('hatched', debugMessage: 'nacidos > huevos');
      }
    }

    // `RV-09`: ni futura ni de hace más de veinte años.
    final now = _clock();
    if (date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59))) {
      return const ValidationFailure('date', debugMessage: 'fecha futura');
    }
    if (date.isBefore(DateTime(now.year - 20, now.month, now.day))) {
      return const ValidationFailure('date', debugMessage: 'fecha demasiado antigua');
    }

    // `RV-10`: el padre debe ser macho y la madre hembra.
    final parentFailure = await _validateParent(fatherId, Sex.male, 'fatherId');
    if (parentFailure != null) return parentFailure;

    final motherFailure = await _validateParent(motherId, Sex.female, 'motherId');
    if (motherFailure != null) return motherFailure;

    if (fatherId != null && fatherId == motherId) {
      return const ValidationFailure('motherId', debugMessage: 'mismo ejemplar como ambos padres');
    }

    // `RS-02`: el límite del plan se evalúa aquí, contando la camada entera.
    // Comprobarlo cría a cría dejaría entrar una camada a medias.
    return _checkPlanLimit(ownerId: ownerId, adding: hatched);
  }

  Future<Failure?> _validateParent(String? id, Sex expected, String field) async {
    if (id == null) return null;

    final row = await _birdsDao.findById(id);
    if (row == null) {
      return ValidationFailure(field, debugMessage: 'progenitor inexistente');
    }
    if (Sex.fromId(row.sex) != expected) {
      return ValidationFailure(field, debugMessage: 'sexo del progenitor incorrecto');
    }
    return null;
  }

  /// El plan se comprueba contra la camada completa: si el criador tiene tres
  /// plazas libres y registra ocho crías, no se le crean tres.
  Future<PlanLimitFailure?> _checkPlanLimit({required String ownerId, required int adding}) async {
    final profile = await _profilesDao.findById(ownerId);
    final limit = SubscriptionPlan.fromId(profile?.plan).birdLimit;
    if (limit == null) return null;

    final current = await _birdsDao.countForOwner(ownerId);
    if (current + adding <= limit) return null;
    return PlanLimitFailure(limit: limit, current: current);
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    final query = _supabase.client.from(table).select().eq('owner_id', ownerId);
    final rows = since == null
        ? await query
        : await query.gt('updated_at', since.toUtc().toIso8601String());

    if (rows.isEmpty) return null;

    final merge = await RemoteMerge.forTable(_syncQueue, table);

    DateTime? latest;
    final incoming = <ClutchesCompanion>[];
    for (final row in rows) {
      final clutch = Clutch.fromRemoteJson(row);
      if (latest == null || clutch.updatedAt.isAfter(latest)) latest = clutch.updatedAt;
      if (!await merge.accepts(clutch.id, clutch.updatedAt)) continue;
      incoming.add(clutch.toCompanion());
    }

    if (incoming.isNotEmpty) await _clutchesDao.upsertAll(incoming);
    return latest;
  }
}
