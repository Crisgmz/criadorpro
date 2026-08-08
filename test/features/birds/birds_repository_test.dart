import 'dart:convert';

import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
// `isNotNull` existe en drift y en matcher; aquí solo necesitamos `Value`.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BirdsRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 1);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = BirdsRepository(
      database: database,
      birdsDao: database.birdsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      // Sin backend: el repositorio debe funcionar igual, solo en local.
      supabase: SupabaseService(null),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> givenProfile(SubscriptionPlan plan) => database.profilesDao.upsert(
    ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now, plan: Value(plan.id)),
  );

  Future<void> givenBirds(int count) async {
    for (var index = 0; index < count; index++) {
      await database.birdsDao.upsert(
        BirdsCompanion.insert(
          id: 'bird-$index',
          ownerId: ownerId,
          plate: index + 1,
          sex: Sex.male.id,
          status: BirdStatus.active.id,
          createdAt: now,
          updatedAt: now,
          name: Value('Ejemplar $index'),
        ),
      );
    }
  }

  Bird draft({String? name = 'Nuevo', int plate = 100}) => Bird.draft(
    ownerId: ownerId,
    now: now,
  ).copyWith(plate: plate, name: () => name, sex: Sex.female);

  group('save', () {
    test('RF-REG-06 · rechaza guardar sin placa', () async {
      await givenProfile(SubscriptionPlan.free);

      final result = await repository.save(draft(plate: 0));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect((result.failureOrNull! as ValidationFailure).field, 'plate');
    });

    test('RF-REG-06 · el nombre es opcional', () async {
      await givenProfile(SubscriptionPlan.free);

      final result = await repository.save(draft(name: null));

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.name, isNull);
    });

    test('un nombre en blanco se guarda como nulo, no como cadena vacía', () async {
      await givenProfile(SubscriptionPlan.free);

      final result = await repository.save(draft(name: '   '));

      expect(result.valueOrNull!.name, isNull);
    });

    test('asigna id y guarda en local', () async {
      await givenProfile(SubscriptionPlan.free);

      final result = await repository.save(draft(name: '  Perla  '));
      final saved = result.valueOrNull!;

      expect(saved.id, isNotEmpty);
      expect(saved.plate, 100);
      expect(saved.name, 'Perla', reason: 'el nombre se guarda sin espacios sobrantes');
      expect(await database.birdsDao.countForOwner(ownerId), 1);
    });

    test('encola el alta para sincronizarla más tarde', () async {
      await givenProfile(SubscriptionPlan.free);

      final saved = (await repository.save(draft())).valueOrNull!;
      final pending = await database.syncQueueDao.pending(maxAttempts: 5);

      expect(pending, hasLength(1));
      expect(pending.single.entityTable, 'birds');
      expect(pending.single.entityId, saved.id);
      final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['sex'], 'female');
      expect(payload['is_deleted'], isFalse);
    });

    test('bloquea el alta al llegar al límite del plan', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(SubscriptionPlan.free.birdLimit!);

      final result = await repository.save(draft());

      final failure = result.failureOrNull;
      expect(failure, isA<PlanLimitFailure>());
      expect((failure! as PlanLimitFailure).limit, 25);
      expect((failure as PlanLimitFailure).current, 25);
    });

    test('deja editar un ejemplar existente aunque el plan esté lleno', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(SubscriptionPlan.free.birdLimit!);

      final existing = (await repository.findById('bird-0')).valueOrNull!;
      final result = await repository.save(existing.copyWith(name: () => 'Renombrado'));

      expect(result.isOk, isTrue);
      expect((await repository.findById('bird-0')).valueOrNull!.name, 'Renombrado');
    });

    test('el plan Élite no impone límite', () async {
      await givenProfile(SubscriptionPlan.elite);
      await givenBirds(600);

      expect((await repository.save(draft())).isOk, isTrue);
    });

    test('sin perfil sincronizado aplica el límite más restrictivo', () async {
      await givenBirds(SubscriptionPlan.free.birdLimit!);

      expect((await repository.save(draft())).failureOrNull, isA<PlanLimitFailure>());
    });
  });

  group('delete', () {
    test('marca la baja y la encola en vez de borrar la fila', () async {
      await givenProfile(SubscriptionPlan.free);
      final saved = (await repository.save(draft())).valueOrNull!;

      final result = await repository.delete(saved.id);

      expect(result.isOk, isTrue);
      final row = await database.birdsDao.findById(saved.id);
      expect(row, isNotNull, reason: 'la fila se conserva para poder propagar la baja');
      expect(row!.isDeleted, isTrue);

      final pending = await database.syncQueueDao.pending(maxAttempts: 5);
      expect(pending.single.operation, 'delete');
    });

    test('deja de contar para el límite del plan', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(SubscriptionPlan.free.birdLimit!);
      await repository.delete('bird-0');

      expect((await repository.save(draft())).isOk, isTrue);
    });

    test('informa si el ejemplar no existe', () async {
      expect((await repository.delete('inexistente')).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('watchBirds', () {
    test('filtra por sexo y por texto, y oculta las bajas', () async {
      await givenProfile(SubscriptionPlan.elite);
      await repository.save(draft(name: 'Perla'));
      final tordo = (await repository.save(
        draft(name: 'Tordo').copyWith(sex: Sex.male),
      )).valueOrNull!;

      expect(await repository.watchBirds(ownerId: ownerId).first, hasLength(2));
      expect(await repository.watchBirds(ownerId: ownerId, sex: Sex.male).first, [
        isA<Bird>().having((bird) => bird.name, 'name', 'Tordo'),
      ]);
      expect(await repository.watchBirds(ownerId: ownerId, search: 'per').first, [
        isA<Bird>().having((bird) => bird.name, 'name', 'Perla'),
      ]);

      await repository.delete(tordo.id);
      expect(await repository.watchBirds(ownerId: ownerId).first, hasLength(1));
    });

    test('no devuelve ejemplares de otro criadero', () async {
      await givenProfile(SubscriptionPlan.elite);
      await repository.save(draft(name: 'Perla'));

      expect(await repository.watchBirds(ownerId: 'otro-criadero').first, isEmpty);
    });
  });

  group('RS-01 · numeración de placas', () {
    test('propone la placa que marca el perfil', () async {
      await givenProfile(SubscriptionPlan.free);
      await database.profilesDao.bumpNextPlate(ownerId: ownerId, atLeast: 1688);

      expect(await repository.nextPlate(ownerId), 1688);
    });

    test('sin perfil todavía sincronizado, arranca en 1', () async {
      expect(await repository.nextPlate(ownerId), 1);
    });

    test('un alta empuja el contador por encima de la placa usada', () async {
      await givenProfile(SubscriptionPlan.free);

      await repository.save(draft(plate: 500));

      expect(await repository.nextPlate(ownerId), 501);
    });

    test('el contador nunca retrocede', () async {
      await givenProfile(SubscriptionPlan.free);
      await database.profilesDao.bumpNextPlate(ownerId: ownerId, atLeast: 900);

      // Registrar una placa antigua no puede hacer que la próxima se repita.
      await repository.save(draft(plate: 100));

      expect(await repository.nextPlate(ownerId), 900);
    });

    test('editar no consume placa', () async {
      await givenProfile(SubscriptionPlan.free);
      final saved = (await repository.save(draft(plate: 300))).valueOrNull!;
      final after = await repository.nextPlate(ownerId);

      await repository.save(saved.copyWith(name: () => 'Otro nombre'));

      expect(await repository.nextPlate(ownerId), after);
    });
  });

  group('RV-08 · placa duplicada', () {
    test('detecta la que ya existe', () async {
      await givenProfile(SubscriptionPlan.free);
      await repository.save(draft(plate: 42));

      expect(await repository.isPlateTaken(ownerId: ownerId, plate: 42), isTrue);
      expect(await repository.isPlateTaken(ownerId: ownerId, plate: 43), isFalse);
    });

    test('advierte pero deja guardar: el libro de papel a veces repite', () async {
      await givenProfile(SubscriptionPlan.free);
      await repository.save(draft(plate: 42));

      final result = await repository.save(draft(plate: 42));

      expect(result.isOk, isTrue);
    });

    test('editar un ejemplar no lo cuenta como duplicado de sí mismo', () async {
      await givenProfile(SubscriptionPlan.free);
      final saved = (await repository.save(draft(plate: 42))).valueOrNull!;

      final taken = await repository.isPlateTaken(ownerId: ownerId, plate: 42, excludeId: saved.id);

      expect(taken, isFalse);
    });
  });

  group('RS-02 · el límite cuenta solo los activos', () {
    test('un ejemplar vendido no ocupa plaza', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(SubscriptionPlan.free.birdLimit!);

      // Uno sale del criadero: debería liberar su cupo.
      final sold = (await repository.findById('bird-0')).valueOrNull!;
      await repository.save(sold.copyWith(status: BirdStatus.sold));

      final result = await repository.save(draft(plate: 900));

      expect(result.isOk, isTrue, reason: 'RS-02 cuenta solo status = active');
    });
  });
}
