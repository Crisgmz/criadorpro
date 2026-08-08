import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
import 'package:criadorpro/features/birds/repository/clutches_repository.dart';
import 'package:criadorpro/features/birds/viewmodel/clutch_form_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// La pantalla promete ocho crías en menos de un minuto, así que lo que se
/// prueba aquí es sobre todo que el estado arranca ya utilizable y que el
/// contador y la vista previa de placas van siempre sincronizados.
void main() {
  late AppDatabase database;
  late ClutchFormViewModel viewModel;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5, 14, 30);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.profilesDao.upsert(
      ProfilesCompanion.insert(
        id: ownerId,
        createdAt: now,
        updatedAt: now,
        plan: Value(SubscriptionPlan.elite.id),
        nextPlate: const Value(40),
      ),
    );

    viewModel = ClutchFormViewModel(
      repository: ClutchesRepository(
        database: database,
        clutchesDao: database.clutchesDao,
        birdsDao: database.birdsDao,
        profilesDao: database.profilesDao,
        syncQueue: database.syncQueueDao,
        supabase: SupabaseService(null),
        clock: () => now,
      ),
      birdsRepository: BirdsRepository(
        database: database,
        birdsDao: database.birdsDao,
        profilesDao: database.profilesDao,
        syncQueue: database.syncQueueDao,
        supabase: SupabaseService(null),
        clock: () => now,
      ),
      ownerId: ownerId,
      clock: () => now,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

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

  group('estado inicial', () {
    test('arranca con hoy, una cría y la placa siguiente del criadero', () async {
      await viewModel.load();

      expect(viewModel.date, DateTime(2026, 8, 5));
      expect(viewModel.hatched, 1);
      expect(viewModel.firstPlate, 40);
      expect(viewModel.lastPlate, 40);
      expect(viewModel.canSubmit, isTrue);
    });

    test('la fecha arranca sin hora, para que no se cuele como futura', () async {
      await viewModel.load();

      expect(viewModel.date.hour, 0);
      expect(viewModel.isDateInFuture, isFalse);
    });

    test('carga los candidatos a progenitor ya separados por sexo', () async {
      await givenBird(id: 'macho', sex: Sex.male, plate: 1);
      await givenBird(id: 'hembra', sex: Sex.female, plate: 2);

      await viewModel.load();

      expect(viewModel.fatherCandidates.map((b) => b.id), ['macho']);
      expect(viewModel.motherCandidates.map((b) => b.id), ['hembra']);
    });
  });

  group('RF-REG-10 · contador y vista previa de placas', () {
    test('el rango de placas sigue al contador', () async {
      await viewModel.load();

      for (var i = 0; i < 7; i++) {
        viewModel.increment();
      }

      expect(viewModel.hatched, 8);
      expect(viewModel.firstPlate, 40);
      expect(viewModel.lastPlate, 47);
    });

    test('RV-11 · el contador no baja de 1 ni sube de 30', () async {
      await viewModel.load();

      viewModel.decrement();
      expect(viewModel.hatched, 1);
      expect(viewModel.canDecrement, isFalse);

      viewModel.setHatched(30);
      viewModel.increment();
      expect(viewModel.hatched, 30);
      expect(viewModel.canIncrement, isFalse);
    });

    test('fijar el número directamente se recorta al rango válido', () async {
      await viewModel.load();

      viewModel.setHatched(99);
      expect(viewModel.hatched, 30);

      viewModel.setHatched(0);
      expect(viewModel.hatched, 1);
    });

    test('notifica a la vista en cada toque del contador', () async {
      await viewModel.load();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.increment();
      viewModel.decrement();

      expect(notifications, 2);
    });
  });

  group('validación', () {
    test('RV-09 · una fecha futura bloquea el envío', () async {
      await viewModel.load();

      viewModel.setDate(DateTime(2026, 8, 6));

      expect(viewModel.isDateInFuture, isTrue);
      expect(viewModel.canSubmit, isFalse);
      expect(await viewModel.submit(), isNull);
    });

    test('hoy no cuenta como futura aunque el reloj vaya por la tarde', () async {
      await viewModel.load();

      viewModel.setDate(DateTime(2026, 8, 5));

      expect(viewModel.isDateInFuture, isFalse);
      expect(viewModel.canSubmit, isTrue);
    });

    test('más crías que huevos bloquea, y corregir cualquiera de los dos libera', () async {
      await viewModel.load();
      viewModel.setHatched(10);

      viewModel.setEggs('8');
      expect(viewModel.isHatchedOverEggs, isTrue);
      expect(viewModel.canSubmit, isFalse);

      // Se puede corregir subiendo los huevos...
      viewModel.setEggs('12');
      expect(viewModel.isHatchedOverEggs, isFalse);

      // ...o bajando las crías.
      viewModel.setEggs('8');
      viewModel.setHatched(8);
      expect(viewModel.isHatchedOverEggs, isFalse);
      expect(viewModel.canSubmit, isTrue);
    });

    test('sin huevos anotados no hay nada que contradecir', () async {
      await viewModel.load();
      viewModel.setHatched(30);

      viewModel.setEggs('');

      expect(viewModel.isHatchedOverEggs, isFalse);
      expect(viewModel.canSubmit, isTrue);
    });
  });

  group('RF-REG-11 · envío', () {
    test('devuelve la camada con sus crías y el rango de placas', () async {
      await viewModel.load();
      viewModel.setHatched(8);

      final registration = await viewModel.submit();

      expect(registration, isNotNull);
      expect(registration!.chicks, hasLength(8));
      expect(registration.firstPlate, 40);
      expect(registration.lastPlate, 47);
    });

    test('recargar tras registrar propone el siguiente bloque, no el mismo', () async {
      await viewModel.load();
      viewModel.setHatched(5);
      await viewModel.submit();

      // Es lo que hace «Registrar otra»: sin esto, la segunda camada volvería a
      // proponer la placa 40 y el criador vería un rango que ya usó.
      await viewModel.load();

      expect(viewModel.firstPlate, 45);
      // El formulario queda en blanco: arrastrar las cinco crías anteriores
      // crearía registros equivocados sin que nadie lo note.
      expect(viewModel.hatched, 1);
      expect(viewModel.eggs, isEmpty);
      expect(viewModel.fatherId, isNull);
      expect(viewModel.motherId, isNull);
    });

    test('un fallo del repositorio deja el error y no devuelve camada', () async {
      await viewModel.load();
      await givenBird(id: 'hembra', sex: Sex.female, plate: 1);
      // `RV-10`: una hembra no puede ser el padre.
      viewModel.setFatherId('hembra');

      final registration = await viewModel.submit();

      expect(registration, isNull);
      expect(viewModel.failure, isNotNull);
    });
  });
}
