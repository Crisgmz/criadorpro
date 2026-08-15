import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/model/clutch.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
import 'package:criadorpro/features/birds/repository/clutches_repository.dart';
import 'package:criadorpro/features/birds/viewmodel/bird_detail_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ficha del ejemplar — `RF-REG-12` y `RF-REG-13`. Lo que se prueba con más
/// detalle es la agrupación de la descendencia: el criador piensa en «los ocho
/// del cruce de marzo», no en ocho ejemplares sueltos.
void main() {
  late AppDatabase database;
  late BirdsRepository birds;
  late ClutchesRepository clutches;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    birds = BirdsRepository(
      database: database,
      birdsDao: database.birdsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
    clutches = ClutchesRepository(
      database: database,
      clutchesDao: database.clutchesDao,
      birdsDao: database.birdsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );

    await database.profilesDao.upsert(
      ProfilesCompanion.insert(
        id: ownerId,
        createdAt: now,
        updatedAt: now,
        plan: Value(SubscriptionPlan.elite.id),
        nextPlate: const Value(1),
      ),
    );
  });

  tearDown(() => database.close());

  Future<void> givenBird({
    required String id,
    required Sex sex,
    required int plate,
    String? fatherId,
    String? motherId,
  }) => database.birdsDao.upsert(
    BirdsCompanion.insert(
      id: id,
      ownerId: ownerId,
      plate: plate,
      sex: sex.id,
      status: BirdStatus.active.id,
      createdAt: now,
      updatedAt: now,
      fatherId: Value(fatherId),
      motherId: Value(motherId),
    ),
  );

  BirdDetailViewModel viewModelFor(String id) =>
      BirdDetailViewModel(repository: birds, clutchesRepository: clutches, birdId: id);

  /// El ViewModel se alimenta de streams: hay que dejar correr el bucle de
  /// eventos para que lleguen antes de mirar el estado.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

  group('RF-REG-12 · datos de la ficha', () {
    test('resuelve los progenitores a ejemplares completos', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      await givenBird(id: 'madre', sex: Sex.female, plate: 2);
      await givenBird(id: 'hijo', sex: Sex.male, plate: 3, fatherId: 'padre', motherId: 'madre');

      final viewModel = viewModelFor('hijo');
      await settle();

      expect(viewModel.bird?.plate, 3);
      expect(viewModel.father?.id, 'padre');
      expect(viewModel.mother?.id, 'madre');
      viewModel.dispose();
    });

    test('un ejemplar sin progenitores registrados no falla', () async {
      await givenBird(id: 'huerfano', sex: Sex.unknown, plate: 9);

      final viewModel = viewModelFor('huerfano');
      await settle();

      expect(viewModel.father, isNull);
      expect(viewModel.mother, isNull);
      expect(viewModel.hasError, isFalse);
      viewModel.dispose();
    });
  });

  group('RF-REG-13 · descendencia agrupada por camada', () {
    test('agrupa las crías de cada camada bajo su propio bloque', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      await givenBird(id: 'madre', sex: Sex.female, plate: 2);

      await clutches.register(
        ownerId: ownerId,
        date: DateTime(2026, 3, 10),
        hatched: 3,
        fatherId: 'padre',
        motherId: 'madre',
      );
      await clutches.register(
        ownerId: ownerId,
        date: DateTime(2026, 6, 20),
        hatched: 2,
        fatherId: 'padre',
        motherId: 'madre',
      );

      final viewModel = viewModelFor('padre');
      await settle();

      expect(viewModel.offspring, hasLength(2));
      expect(viewModel.offspringCount, 5);
      // Lo más reciente arriba: es la camada que el criador acaba de tocar.
      expect(viewModel.offspring.first.clutch?.date, DateTime(2026, 6, 20));
      expect(viewModel.offspring.first.chicks, hasLength(2));
      expect(viewModel.offspring.last.chicks, hasLength(3));
      viewModel.dispose();
    });

    test('la madre ve la misma descendencia que el padre', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      await givenBird(id: 'madre', sex: Sex.female, plate: 2);
      await clutches.register(
        ownerId: ownerId,
        date: DateTime(2026, 5, 1),
        hatched: 4,
        fatherId: 'padre',
        motherId: 'madre',
      );

      final viewModel = viewModelFor('madre');
      await settle();

      expect(viewModel.offspringCount, 4);
      viewModel.dispose();
    });

    test('las crías registradas a mano caen en un grupo sin camada, al final', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      await givenBird(id: 'madre', sex: Sex.female, plate: 2);
      await clutches.register(
        ownerId: ownerId,
        date: DateTime(2026, 4, 1),
        hatched: 2,
        fatherId: 'padre',
        motherId: 'madre',
      );
      // Un ejemplar dado de alta uno a uno, con padre pero sin cruce.
      await givenBird(id: 'suelto', sex: Sex.male, plate: 99, fatherId: 'padre');

      final viewModel = viewModelFor('padre');
      await settle();

      expect(viewModel.offspring, hasLength(2));
      expect(viewModel.offspring.last.clutch, isNull);
      expect(viewModel.offspring.last.chicks.single.id, 'suelto');
      expect(viewModel.offspringCount, 3);
      viewModel.dispose();
    });

    test('las crías de una camada van ordenadas por placa', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      await clutches.register(
        ownerId: ownerId,
        date: DateTime(2026, 4, 1),
        hatched: 5,
        fatherId: 'padre',
      );

      final viewModel = viewModelFor('padre');
      await settle();

      final plates = viewModel.offspring.single.chicks.map((c) => c.plate).toList();
      expect(plates, List<int>.from(plates)..sort());
      viewModel.dispose();
    });

    test('sin descendencia la lista queda vacía, no en error', () async {
      await givenBird(id: 'solo', sex: Sex.male, plate: 7);

      final viewModel = viewModelFor('solo');
      await settle();

      expect(viewModel.offspring, isEmpty);
      expect(viewModel.offspringCount, 0);
      expect(viewModel.hasError, isFalse);
      viewModel.dispose();
    });

    test('registrar una camada nueva refresca la ficha abierta', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);

      final viewModel = viewModelFor('padre');
      await settle();
      expect(viewModel.offspringCount, 0);

      // Sin salir de la ficha: el stream tiene que traer las crías solo.
      final result = await clutches.register(
        ownerId: ownerId,
        date: DateTime(2026, 7, 1),
        hatched: 3,
        fatherId: 'padre',
      );
      expect(result, isA<Ok<ClutchRegistration>>());
      await settle();

      expect(viewModel.offspringCount, 3);
      viewModel.dispose();
    });

    test('una cría dada de baja desaparece de la descendencia', () async {
      await givenBird(id: 'padre', sex: Sex.male, plate: 1);
      final registration =
          ((await clutches.register(
                    ownerId: ownerId,
                    date: DateTime(2026, 7, 1),
                    hatched: 3,
                    fatherId: 'padre',
                  ))
                  as Ok<ClutchRegistration>)
              .value;

      final viewModel = viewModelFor('padre');
      await settle();
      expect(viewModel.offspringCount, 3);

      await birds.delete(registration.chicks.first.id);
      await settle();

      expect(viewModel.offspringCount, 2);
      viewModel.dispose();
    });
  });
}
