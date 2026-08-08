import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../model/profile.dart';

/// Perfil del usuario. Se baja del backend y se cachea en Drift para que el
/// límite del plan siga aplicándose sin conexión.
class ProfileRepository implements RemotePuller {
  ProfileRepository({
    required AppDatabase database,
    required ProfilesDao profilesDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _profilesDao = profilesDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _clock = clock;

  final AppDatabase _database;
  final ProfilesDao _profilesDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final DateTime Function() _clock;

  @override
  String get table => 'profiles';

  Stream<Profile?> watchProfile(String id) =>
      _profilesDao.watchById(id).map((row) => row == null ? null : Profile.fromRow(row));

  Future<Result<Profile>> findById(String id) => guard(() async {
    final row = await _profilesDao.findById(id);
    if (row == null) throw StateError('perfil no encontrado');
    return Profile.fromRow(row);
  }, (error, _) => const NotFoundFailure(debugMessage: 'perfil no encontrado'));

  /// Cierra la configuración inicial — `RF-ONB-01` a `RF-ONB-03`.
  ///
  /// [currentPlate] es la última placa que el criador ya usó en su libro, así
  /// que la numeración continúa en la siguiente: eso es lo que le permite
  /// migrar sin retranscribir nada.
  ///
  /// Es el único momento en que el cliente fija `next_plate` a mano. A partir
  /// de aquí solo lo mueve la RPC `next_plate()` del servidor, que serializa
  /// las reservas para que dos dispositivos del mismo criadero no generen la
  /// misma placa (`RS-01`).
  Future<Result<Profile>> completeOnboarding({
    required String ownerId,
    required String farmName,
    required int currentPlate,
    String? location,
    String? locale,
  }) async {
    final existing = await _profilesDao.findById(ownerId);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'perfil no encontrado'));
    }

    final now = _clock();
    final profile = Profile.fromRow(existing).copyWith(
      farmName: farmName.trim(),
      location: location?.trim(),
      locale: locale,
      nextPlate: currentPlate + 1,
      updatedAt: now,
    );

    return guard(() async {
      await _database.transaction(() async {
        await _profilesDao.upsert(profile.toCompanion());
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: profile.id,
          operation: SyncOperation.upsert,
          // `next_plate` viaja aquí y solo aquí: `toRemoteJson()` lo omite
          // justamente para que ninguna otra escritura lo toque.
          payload: jsonEncode({...profile.toRemoteJson(), 'next_plate': profile.nextPlate}),
          now: now,
        );
      });
      return profile;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    // El perfil siempre se trae entero: es una sola fila y necesitamos el plan
    // actualizado aunque `updated_at` no haya cambiado desde la última bajada.
    final rows = await _supabase.client.from(table).select().eq('id', ownerId).limit(1);
    if (rows.isEmpty) return null;

    // Un cambio local sin sincronizar gana sobre lo que llega: si no, la bajada
    // pisaría el criadero que el usuario acaba de escribir sin conexión.
    final pending = await _syncQueue.pendingIdsFor(table);
    if (pending.contains(ownerId)) return null;

    final profile = Profile.fromRemoteJson(rows.first);
    await _profilesDao.upsert(profile.toCompanion());
    return profile.updatedAt;
  }
}
