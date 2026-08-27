import 'dart:convert';

import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/db/daos/sync_queue_dao.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/features/auth/model/profile.dart';
import 'package:criadorpro/features/auth/repository/profile_repository.dart';
// Solo `Value`: el `isNull` de Drift choca con el de las pruebas.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// La bajada del perfil, que es por donde llega la membresía.
///
/// El plan no lo escribe nunca el cliente (`RS-12`): lo fija `verify_receipt()`
/// en el servidor y `Profile.toRemoteJson()` lo excluye. Por eso una escritura
/// local pendiente no puede bloquearlo, y estas pruebas son las que lo fijan.
void main() {
  late AppDatabase database;
  late ProfileRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime.utc(2026, 8, 27, 10);

  Map<String, dynamic> remoteRow({required String plan, String? farmName, DateTime? expiresAt}) => {
    'id': ownerId,
    'plan': plan,
    'plan_expires_at': expiresAt?.toIso8601String(),
    'farm_name': farmName,
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ProfileRepository(
      database: database,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );

    // Estado de partida: el criadero con su nombre puesto y plan gratuito.
    await database.profilesDao.upsert(
      ProfilesCompanion.insert(
        id: ownerId,
        farmName: const Value('Criadero del criador'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  Future<Profile> localProfile() async =>
      Profile.fromRow((await database.profilesDao.findById(ownerId))!);

  Future<void> enqueueProfileWrite({int attempts = 0}) async {
    await database.syncQueueDao.enqueue(
      entityTable: 'profiles',
      entityId: ownerId,
      operation: SyncOperation.upsert,
      payload: jsonEncode({'id': ownerId, 'farm_name': 'Criadero del criador'}),
      now: now,
    );
    if (attempts > 0) {
      for (var i = 0; i < attempts; i++) {
        final pending = await database.syncQueueDao.pending(maxAttempts: 99);
        await database.syncQueueDao.markFailed(pending.single.id, 'sin red');
      }
    }
  }

  test('sin nada pendiente, el perfil remoto entra entero', () async {
    final watermark = await repository.applyRemote(
      remoteRow(plan: 'elite', farmName: 'Nombre del servidor'),
      ownerId: ownerId,
    );

    final profile = await localProfile();
    expect(profile.plan, SubscriptionPlan.elite);
    expect(profile.farmName, 'Nombre del servidor');
    // `.toUtc()`: la fecha llega del servidor en ISO y `Profile` la pasa a hora
    // local, así que comparar los objetos tal cual falla por la zona.
    expect(watermark?.toUtc(), now, reason: 'la marca de agua avanza cuando se escribió todo');
  });

  test('una escritura local pendiente conserva lo que el criador escribió', () async {
    await enqueueProfileWrite();

    final watermark = await repository.applyRemote(
      remoteRow(plan: 'free', farmName: 'Nombre del servidor'),
      ownerId: ownerId,
    );

    expect(
      (await localProfile()).farmName,
      'Criadero del criador',
      reason: 'lo que aún no se ha subido no se pisa con la versión remota',
    );
    expect(watermark, isNull, reason: 'sin escribir el resto, no hay marca que guardar');
  });

  test('pero el plan sí llega: no es un campo que el cliente escriba', () async {
    await enqueueProfileWrite();

    await repository.applyRemote(
      remoteRow(plan: 'elite', farmName: 'Nombre del servidor'),
      ownerId: ownerId,
    );

    final profile = await localProfile();
    expect(profile.plan, SubscriptionPlan.elite);
    expect(profile.effectivePlan, SubscriptionPlan.elite);
    expect(
      profile.farmName,
      'Criadero del criador',
      reason: 'el plan entra sin arrastrar consigo el resto de la fila',
    );
  });

  test('y también con la entrada de cola agotada, que es el caso que se colgaba', () async {
    // Cinco intentos fallidos: `_push` ya no la reintenta sola (`RS-11`) y se
    // queda en la cola hasta que alguien pulse «Sincronizar ahora». Mientras
    // tanto, la membresía se quedaba congelada para siempre.
    await enqueueProfileWrite(attempts: AppConfig.maxSyncAttempts);
    expect(await database.syncQueueDao.pending(maxAttempts: AppConfig.maxSyncAttempts), isEmpty);

    await repository.applyRemote(remoteRow(plan: 'elite'), ownerId: ownerId);

    expect((await localProfile()).plan, SubscriptionPlan.elite);
  });

  test('el plan no mueve `updated_at` del perfil', () async {
    await enqueueProfileWrite();
    final before = (await localProfile()).updatedAt;

    await repository.applyRemote(remoteRow(plan: 'elite'), ownerId: ownerId);

    expect(
      (await localProfile()).updatedAt,
      before,
      reason: 'moverlo haría ganar a esta fila la resolución de conflictos (RS-09)',
    );
  });

  test('recién caducada aguanta el margen de `RS-12`', () async {
    await enqueueProfileWrite();

    await repository.applyRemote(
      remoteRow(plan: 'elite', expiresAt: now.subtract(const Duration(days: 1))),
      ownerId: ownerId,
    );

    final profile = await localProfile();
    expect(profile.plan, SubscriptionPlan.elite);
    // La renovación de la tienda llega horas después del vencimiento: degradar
    // en el instante le quitaría la empleomanía a un criadero que sí pagó.
    // Con el reloj de la prueba y no con `DateTime.now()`: el margen son 72 h
    // sobre un vencimiento fijo, así que la comprobación empezaría a fallar
    // sola tres días después de escribirla.
    expect(profile.effectivePlanAt(now), SubscriptionPlan.elite);
  });

  test('pasado el margen sí se comporta como gratuita', () async {
    await enqueueProfileWrite();

    final expiry = now.subtract(const Duration(days: 1));
    await repository.applyRemote(
      remoteRow(plan: 'elite', expiresAt: expiry),
      ownerId: ownerId,
    );

    final profile = await localProfile();
    expect(
      profile.effectivePlanAt(expiry.add(AppConfig.planGracePeriod).add(const Duration(hours: 1))),
      SubscriptionPlan.free,
    );
  });
}
