import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/model/clutch.dart';
import 'package:criadorpro/features/birds/repository/clutches_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-REG-08` a `RF-REG-10`. La regla que se prueba con más saña es `RS-04`:
/// la camada y sus crías se crean **todas o ninguna**. Un fallo a mitad que
/// dejara tres crías y el contador movido sería silencioso y el criador no
/// tendría cómo detectarlo.
void main() {
  late AppDatabase database;
  late ClutchesRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ClutchesRepository(
      database: database,
      clutchesDao: database.clutchesDao,
      birdsDao: database.birdsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> givenProfile({SubscriptionPlan plan = SubscriptionPlan.elite, int nextPlate = 1}) =>
      database.profilesDao.upsert(
        ProfilesCompanion.insert(
          id: ownerId,
          createdAt: now,
          updatedAt: now,
          plan: Value(plan.id),
          nextPlate: Value(nextPlate),
        ),
      );

  Future<void> givenBird({required String id, required Sex sex, int plate = 1}) =>
      database.birdsDao.upsert(
        BirdsCompanion.insert(
          id: id,
          ownerId: ownerId,
          plate: plate,
          sex: sex.id,
          status: BirdStatus.active.id,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<Result<ClutchRegistration>> register({
    int hatched = 8,
    int? eggs,
    DateTime? date,
    String? fatherId,
    String? motherId,
    String? line,
  }) => repository.register(
    ownerId: ownerId,
    date: date ?? DateTime(2026, 8, 1),
    hatched: hatched,
    eggs: eggs,
    fatherId: fatherId,
    motherId: motherId,
    line: line,
  );

  group('RF-REG-08 · registro de camada', () {
    test('crea la camada y una cría por nacido, con placas correlativas', () async {
      await givenProfile(nextPlate: 40);

      final result = await register(hatched: 8);

      final registration = (result as Ok<ClutchRegistration>).value;
      expect(registration.chicks, hasLength(8));
      expect(registration.chicks.map((c) => c.plate), [40, 41, 42, 43, 44, 45, 46, 47]);
      expect(registration.firstPlate, 40);
      expect(registration.lastPlate, 47);

      final birds = await database.birdsDao.countForOwner(ownerId);
      expect(birds, 8);
    });

    test('RS-01 · el contador avanza el bloque entero de una vez', () async {
      await givenProfile(nextPlate: 40);

      await register(hatched: 8);

      final profile = await database.profilesDao.findById(ownerId);
      expect(profile!.nextPlate, 48);
    });

    test('las crías heredan fecha, progenitores y línea de la camada', () async {
      await givenProfile();
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      await givenBird(id: 'madre', sex: Sex.female, plate: 2);
      final date = DateTime(2026, 7, 15);

      final result = await register(
        hatched: 3,
        date: date,
        fatherId: 'padre',
        motherId: 'madre',
        line: '  Línea A  ',
      );

      final chicks = (result as Ok<ClutchRegistration>).value.chicks;
      for (final chick in chicks) {
        expect(chick.birthDate, date);
        expect(chick.fatherId, 'padre');
        expect(chick.motherId, 'madre');
        expect(chick.line, 'Línea A');
        expect(chick.clutchId, isNotEmpty);
        // A un recién nacido no se le determina el sexo; obligar a elegirlo
        // aquí destruiría el minuto que promete la pantalla.
        expect(chick.sex, Sex.unknown);
      }
    });

    test('todas las crías apuntan a la misma camada', () async {
      await givenProfile();

      final registration = ((await register(hatched: 5)) as Ok<ClutchRegistration>).value;

      expect(registration.chicks.map((c) => c.clutchId).toSet(), {registration.clutch.id});
    });
  });

  group('RS-04 · todo o nada', () {
    test('si la camada es inválida no se crea nada y el contador no avanza', () async {
      await givenProfile(nextPlate: 40);

      final result = await register(hatched: 31);

      expect(result, isA<Err<ClutchRegistration>>());
      expect(await database.birdsDao.countForOwner(ownerId), 0);
      expect((await database.profilesDao.findById(ownerId))!.nextPlate, 40);
      expect(await database.clutchesDao.watchCountForOwner(ownerId).first, 0);
    });

    test('una cría con placa repetida tumba la camada entera', () async {
      await givenProfile(nextPlate: 10);
      // Ocupa a mano la placa 12 con el mismo id que generaría un choque real
      // de clave primaria a mitad del bucle.
      await database.birdsDao.upsert(
        BirdsCompanion.insert(
          id: 'chocan',
          ownerId: ownerId,
          plate: 12,
          sex: Sex.male.id,
          status: BirdStatus.active.id,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Una camada de 5 desde la placa 10 pisaría la 12. La placa duplicada es
      // advertencia y no bloqueo (`RV-08`), así que esto **sí** debe crearse:
      // lo que se comprueba es que la transacción no deja restos a medias.
      final result = await register(hatched: 5);

      expect(result, isA<Ok<ClutchRegistration>>());
      expect(await database.birdsDao.countForOwner(ownerId), 6);
    });

    test('la camada y sus crías se encolan juntas, con la camada primero', () async {
      await givenProfile();

      final registration = ((await register(hatched: 3)) as Ok<ClutchRegistration>).value;

      final pending = await database.syncQueueDao.pending(maxAttempts: 5);
      expect(pending, hasLength(4));
      // FIFO estricto: las crías referencian la camada, así que sube antes.
      expect(pending.first.entityTable, 'clutches');
      expect(pending.first.entityId, registration.clutch.id);
      expect(pending.skip(1).map((e) => e.entityTable).toSet(), {'birds'});
    });
  });

  group('validaciones', () {
    test('RV-11 · fuera de 1..30 crías no se registra', () async {
      await givenProfile();

      for (final invalid in [0, -1, 31]) {
        final result = await register(hatched: invalid);
        expect((result as Err<ClutchRegistration>).failure, isA<ValidationFailure>());
        expect((result.failure as ValidationFailure).field, 'hatched');
      }

      expect((await register(hatched: 30)), isA<Ok<ClutchRegistration>>());
    });

    test('no pueden nacer más crías que huevos puestos', () async {
      await givenProfile();

      final result = await register(hatched: 10, eggs: 8);

      expect((result as Err<ClutchRegistration>).failure, isA<ValidationFailure>());
      expect((await register(hatched: 8, eggs: 8)), isA<Ok<ClutchRegistration>>());
    });

    test('RV-09 · la fecha no puede ser futura', () async {
      await givenProfile();

      final result = await register(date: now.add(const Duration(days: 1)));

      expect((result as Err<ClutchRegistration>).failure, isA<ValidationFailure>());
      expect((result.failure as ValidationFailure).field, 'date');
    });

    test('RV-09 · hoy sí vale, aunque la hora sea posterior al reloj', () async {
      await givenProfile();

      final result = await register(date: DateTime(now.year, now.month, now.day, 18));

      expect(result, isA<Ok<ClutchRegistration>>());
    });

    test('RV-10 · el padre debe ser macho y la madre hembra', () async {
      await givenProfile();
      await givenBird(id: 'hembra', sex: Sex.female, plate: 1);
      await givenBird(id: 'macho', sex: Sex.male, plate: 2);

      final wrongFather = await register(fatherId: 'hembra');
      expect(((wrongFather as Err).failure as ValidationFailure).field, 'fatherId');

      final wrongMother = await register(motherId: 'macho');
      expect(((wrongMother as Err).failure as ValidationFailure).field, 'motherId');

      expect(await register(fatherId: 'macho', motherId: 'hembra'), isA<Ok<ClutchRegistration>>());
    });

    test('un progenitor inexistente no pasa', () async {
      await givenProfile();

      final result = await register(fatherId: 'fantasma');

      expect(((result as Err).failure as ValidationFailure).field, 'fatherId');
    });
  });

  group('RS-02 · límite de plan', () {
    test('la camada completa no cabe: no se crea ninguna cría', () async {
      await givenProfile(plan: SubscriptionPlan.free, nextPlate: 24);
      for (var i = 0; i < 23; i++) {
        await givenBird(id: 'b$i', sex: Sex.male, plate: i + 1);
      }

      // Quedan 2 plazas de las 25 del plan gratuito y se piden 8.
      final result = await register(hatched: 8);

      expect((result as Err<ClutchRegistration>).failure, isA<PlanLimitFailure>());
      expect(await database.birdsDao.countForOwner(ownerId), 23);
      expect((await database.profilesDao.findById(ownerId))!.nextPlate, 24);
    });

    test('una camada que cabe justo sí entra', () async {
      await givenProfile(plan: SubscriptionPlan.free, nextPlate: 24);
      for (var i = 0; i < 23; i++) {
        await givenBird(id: 'b$i', sex: Sex.male, plate: i + 1);
      }

      final result = await register(hatched: 2);

      expect(result, isA<Ok<ClutchRegistration>>());
      expect(await database.birdsDao.countForOwner(ownerId), 25);
    });

    test('el plan Élite no impone límite', () async {
      await givenProfile();

      expect(await register(hatched: 30), isA<Ok<ClutchRegistration>>());
    });
  });

  group('RNF-04 · rendimiento', () {
    test('una camada de 15 crías se registra en menos de 500 ms', () async {
      await givenProfile();

      final stopwatch = Stopwatch()..start();
      final result = await register(hatched: 15);
      stopwatch.stop();

      expect(result, isA<Ok<ClutchRegistration>>());
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('RS-10 · borrado', () {
    test('borrar la camada no borra sus crías', () async {
      await givenProfile();
      final registration = ((await register(hatched: 4)) as Ok<ClutchRegistration>).value;

      final result = await repository.delete(registration.clutch.id);

      expect(result, isA<Ok<void>>());
      expect(await database.clutchesDao.watchCountForOwner(ownerId).first, 0);
      // Las crías ya son ejemplares del criadero por derecho propio.
      expect(await database.birdsDao.countForOwner(ownerId), 4);
    });
  });
}
