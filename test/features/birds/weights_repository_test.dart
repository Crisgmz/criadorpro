import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/model/weight_entry.dart';
import 'package:criadorpro/features/birds/repository/weights_repository.dart';
import 'package:criadorpro/features/evaluations/model/evaluation.dart' as ev;
import 'package:criadorpro/features/evaluations/repository/evaluations_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

/// `RF-REG-14` — historial de pesos, y el puente de `RF-PRU-07`.
///
/// Lo que más se prueba es que `birds.weight_g` quede siempre con la pesada más
/// reciente: es un dato derivado, y si se desincroniza la lista y la ficha
/// mienten sin que nada falle.
void main() {
  late AppDatabase database;
  late WeightsRepository repository;
  late EvaluationsRepository evaluations;

  const ownerId = 'owner-1';
  const birdId = 'bird-1';
  final now = DateTime(2026, 8, 27);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = WeightsRepository(
      database: database,
      weightsDao: database.weightsDao,
      birdsDao: database.birdsDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
    evaluations = EvaluationsRepository(
      database: database,
      evaluationsDao: database.evaluationsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      weights: repository,
      clock: () => now,
    );

    await database.profilesDao.upsert(
      ProfilesCompanion.insert(
        id: ownerId,
        createdAt: now,
        updatedAt: now,
        plan: const Value('pro'),
      ),
    );
    await database.birdsDao.upsert(
      BirdsCompanion.insert(
        id: birdId,
        ownerId: ownerId,
        plate: 1,
        sex: Sex.male.id,
        status: BirdStatus.active.id,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  WeightEntry draft({int grams = 1800, DateTime? date}) => WeightEntry(
    id: '',
    ownerId: ownerId,
    birdId: birdId,
    weightG: grams,
    date: date ?? now,
    createdAt: now,
    updatedAt: now,
  );

  Future<int?> currentWeight() async => (await database.birdsDao.findById(birdId))?.weightG;

  group('anotar', () {
    test('la pesada queda en el historial y como peso vigente', () async {
      expect(await repository.save(draft(grams: 1800)), isA<Ok<WeightEntry>>());

      final trend = await repository.watchForBird(birdId).first;
      expect(trend.entries, hasLength(1));
      expect(await currentWeight(), 1800);
    });

    test('el peso vigente es el de la fecha más reciente, no el último escrito', () async {
      await repository.save(draft(grams: 1900, date: DateTime(2026, 8, 20)));
      // Se anota después una pesada más antigua: el criador está poniendo al
      // día su libreta. No puede pisar el peso actual.
      await repository.save(draft(grams: 1500, date: DateTime(2026, 8, 1)));

      expect(await currentWeight(), 1900);
    });

    test('un peso de cero o negativo se rechaza', () async {
      expect((await repository.save(draft(grams: 0)) as Err).failure, isA<ValidationFailure>());
      expect((await repository.save(draft(grams: -5)) as Err).failure, isA<ValidationFailure>());
    });

    test('`RV-12` fuera de rango se guarda igual: advierte, no bloquea', () async {
      // Un pollito de 90 g existe. Bloquearlo obligaría al criador a mentir.
      expect(await repository.save(draft(grams: 90)), isA<Ok<WeightEntry>>());
    });

    test('una fecha futura se rechaza', () async {
      final result = await repository.save(draft(date: DateTime(2026, 12, 31)));
      expect((result as Err).failure, isA<ValidationFailure>());
    });

    test('borrar la última devuelve el peso vigente a la anterior', () async {
      await repository.save(draft(grams: 1500, date: DateTime(2026, 8, 1)));
      final last = (await repository.save(draft(grams: 1800)) as Ok<WeightEntry>).value;

      await repository.delete(last.id);

      expect(await currentWeight(), 1500);
    });

    test('borrar la única deja el ejemplar sin peso', () async {
      final only = (await repository.save(draft()) as Ok<WeightEntry>).value;
      await repository.delete(only.id);

      expect(await currentWeight(), isNull);
    });
  });

  group('RF-PRU-07 · el peso de la prueba entra en el historial', () {
    ev.Evaluation evaluationDraft({int? grams = 1750, String id = ''}) => ev.Evaluation(
      id: id,
      ownerId: ownerId,
      birdId: birdId,
      date: now,
      result: ev.EvaluationResult.favorable,
      weightG: grams,
      createdAt: now,
      updatedAt: now,
    );

    test('registrar una prueba con peso crea la pesada', () async {
      final saved = (await evaluations.save(evaluationDraft()) as Ok<ev.Evaluation>).value;

      final trend = await repository.watchForBird(birdId).first;
      expect(trend.entries, hasLength(1));
      expect(trend.entries.single.weightG, 1750);
      expect(trend.entries.single.evaluationId, saved.id);
      expect(trend.entries.single.isFromEvaluation, isTrue);
      expect(await currentWeight(), 1750);
    });

    test('editar la prueba corrige la pesada, no añade otra', () async {
      final saved = (await evaluations.save(evaluationDraft()) as Ok<ev.Evaluation>).value;

      await evaluations.save(evaluationDraft(id: saved.id, grams: 1820));

      final trend = await repository.watchForBird(birdId).first;
      expect(trend.entries, hasLength(1), reason: 'editar tres veces daría tres pesadas');
      expect(trend.entries.single.weightG, 1820);
      expect(await currentWeight(), 1820);
    });

    test('quitarle el peso a la prueba retira la pesada', () async {
      final saved = (await evaluations.save(evaluationDraft()) as Ok<ev.Evaluation>).value;

      await evaluations.save(evaluationDraft(id: saved.id, grams: null));

      expect(await repository.watchForBird(birdId).first, isA<WeightTrend>());
      expect((await repository.watchForBird(birdId).first).entries, isEmpty);
      expect(await currentWeight(), isNull);
    });

    test('una prueba sin peso no crea nada', () async {
      await evaluations.save(evaluationDraft(grams: null));

      expect((await repository.watchForBird(birdId).first).entries, isEmpty);
    });

    test('borrar la prueba retira su pesada', () async {
      final saved = (await evaluations.save(evaluationDraft()) as Ok<ev.Evaluation>).value;

      await evaluations.delete(saved.id);

      expect((await repository.watchForBird(birdId).first).entries, isEmpty);
      expect(await currentWeight(), isNull);
    });

    test('borrar la prueba no toca las pesadas anotadas a mano', () async {
      await repository.save(draft(grams: 1500, date: DateTime(2026, 8, 1)));
      final saved = (await evaluations.save(evaluationDraft()) as Ok<ev.Evaluation>).value;

      await evaluations.delete(saved.id);

      final trend = await repository.watchForBird(birdId).first;
      expect(trend.entries, hasLength(1));
      expect(trend.entries.single.isFromEvaluation, isFalse);
      expect(await currentWeight(), 1500);
    });
  });

  group('tendencia', () {
    test('con una sola pesada no hay tendencia', () async {
      await repository.save(draft());

      // Pintar «+0 g» sugeriría que el ave se estancó, y no es eso.
      expect((await repository.watchForBird(birdId).first).changeG, isNull);
    });

    test('con dos, la diferencia contra la anterior', () async {
      await repository.save(draft(grams: 1700, date: DateTime(2026, 8, 1)));
      await repository.save(draft(grams: 1800, date: DateTime(2026, 8, 20)));

      final trend = await repository.watchForBird(birdId).first;
      expect(trend.changeG, 100);
      expect(trend.isGaining, isTrue);
    });

    test('perder peso se reconoce como tal', () async {
      await repository.save(draft(grams: 1800, date: DateTime(2026, 8, 1)));
      await repository.save(draft(grams: 1650, date: DateTime(2026, 8, 20)));

      final trend = await repository.watchForBird(birdId).first;
      expect(trend.changeG, -150);
      expect(trend.isLosing, isTrue);
    });
  });

  test('cada escritura encola su operación de sincronización', () async {
    await database.syncQueueDao.clear();
    await repository.save(draft());

    final pending = await database.syncQueueDao.pending(maxAttempts: AppConfig.maxSyncAttempts);
    expect(pending.map((task) => task.entityTable), contains('weight_entries'));
  });
}
