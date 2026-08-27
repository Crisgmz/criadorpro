import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/remote_merge.dart';
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

  /// Publica o retira el criadero del directorio de Comunidad — `RF-COM`.
  ///
  /// Es **opt-in** y vive en el perfil, no en Comunidad: el interruptor tiene
  /// que poder pulsarse sin señal y sobrevivir hasta que haya. Comunidad sí
  /// exige conexión (`RNF-08`), pero decidir publicarse no.
  Future<Result<Profile>> setPublic({required String ownerId, required bool isPublic}) async {
    final existing = await _profilesDao.findById(ownerId);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'perfil no encontrado'));
    }

    final now = _clock();
    final profile = Profile.fromRow(existing).copyWith(isPublic: isPublic, updatedAt: now);

    return guard(() async {
      await _database.transaction(() async {
        await _profilesDao.upsert(profile.toCompanion());
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: profile.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(profile.toRemoteJson()),
          now: now,
        );
      });
      return profile;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Valida el recibo de tienda y refresca el plan — `RF-CTA`, `RS-12`.
  ///
  /// **El cliente nunca escribe su propio plan.** Manda el recibo, la Edge
  /// Function `verify-receipt` lo comprueba contra Apple o Google y es ella
  /// —con `service_role`— quien escribe `plan` y `plan_expires_at`. El
  /// disparador `lock_plan_columns` impide que nadie más los toque, así que
  /// intentarlo desde aquí no serviría de nada aunque se intentara.
  ///
  /// Tras validar se baja el perfil: el plan que vale es el que quedó en el
  /// servidor, no el que la app supone por haber comprado.
  Future<Result<Profile>> verifyReceipt({
    required String ownerId,
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    if (!_supabase.isEnabled) {
      return const Err(NetworkFailure(debugMessage: 'sin backend configurado'));
    }

    return guard(() async {
      await _supabase.client.functions.invoke(
        'verify-receipt',
        body: {'platform': platform, 'productId': productId, 'receipt': receipt},
      );

      await pull(ownerId: ownerId);
      final row = await _profilesDao.findById(ownerId);
      if (row == null) throw StateError('perfil no encontrado tras validar');
      return Profile.fromRow(row);
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    // El perfil siempre se trae entero: es una sola fila y necesitamos el plan
    // actualizado aunque `updated_at` no haya cambiado desde la última bajada.
    final rows = await _supabase.client.from(table).select().eq('id', ownerId).limit(1);
    if (rows.isEmpty) return null;

    return applyRemote(rows.first, ownerId: ownerId);
  }

  /// Escribe en Drift la fila que llega del servidor y resuelve el conflicto
  /// con lo que aún no se ha subido.
  ///
  /// Separado de [pull] para poder probarlo: lo que importa es la regla que
  /// decide qué gana, y ejercitarla no debería exigir un backend.
  @visibleForTesting
  Future<DateTime?> applyRemote(Map<String, dynamic> row, {required String ownerId}) async {
    final profile = Profile.fromRemoteJson(row);

    // Gana el `updated_at` más reciente (`RS-09`): lo que el criador escribió
    // sin conexión no se pisa con una versión remota más antigua, pero una
    // edición hecha después desde otro dispositivo sí entra.
    final merge = await RemoteMerge.forTable(_syncQueue, table);
    if (!await merge.accepts(ownerId, profile.updatedAt)) {
      // El plan es la excepción, y no por comodidad: el cliente **no lo
      // escribe nunca** —`toRemoteJson()` lo deja fuera y quien lo fija es
      // `verify_receipt()` (`RS-12`)—, así que una escritura local pendiente
      // no puede estar en conflicto con él.
      //
      // Rechazar la fila entera dejaba la membresía congelada mientras esa
      // entrada siguiera en la cola. Y una que agota sus cinco intentos se
      // queda ahí hasta que alguien pulse «Sincronizar ahora» (`RS-11`): en la
      // práctica, para siempre. El criador pagaba Élite y la app seguía
      // diciéndole que no le caben más ejemplares, sin nada que mirar.
      await _profilesDao.applyRemotePlan(
        ownerId: ownerId,
        plan: profile.plan.id,
        expiresAt: profile.planExpiresAt,
      );
      // Sin marca de agua: del resto del perfil sigue mandando lo local, y hay
      // que volver a preguntar en la próxima pasada.
      return null;
    }

    await _profilesDao.upsert(profile.toCompanion());
    return profile.updatedAt;
  }
}
