import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/evaluations/model/evaluation.dart';
import 'package:criadorpro/features/evaluations/repository/evaluations_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
// `flutter_test` exporta su propia `Evaluation` (la de accesibilidad); aquí
// interesa la del dominio.
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

/// `RF-PRU` — pruebas de campo.
void main() {
  late AppDatabase database;
  late EvaluationsRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = EvaluationsRepository(
      database: database,
      evaluationsDao: database.evaluationsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> givenPlan(SubscriptionPlan plan) => database.profilesDao.upsert(
    ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now, plan: Value(plan.id)),
  );

  Evaluation draft({
    String birdId = 'bird-1',
    EvaluationResult result = EvaluationResult.undefined,
    int? condition,
    int? weightG,
    DateTime? date,
    String? place,
  }) => Evaluation(
    id: '',
    ownerId: ownerId,
    birdId: birdId,
    date: date ?? DateTime(2026, 8, 1),
    result: result,
    condition: condition,
    weightG: weightG,
    place: place,
    createdAt: now,
    updatedAt: now,
  );

  group('RF-PRU-01 / RF-PRU-02 · registro', () {
    test('guarda ejemplar, fecha, lugar, resultado, peso y condición', () async {
      await givenPlan(SubscriptionPlan.pro);

      final saved =
          ((await repository.save(
                    draft(
                      result: EvaluationResult.favorable,
                      condition: 8,
                      weightG: 2100,
                      place: '  Santiago  ',
                    ),
                  ))
                  as Ok<Evaluation>)
              .value;

      expect(saved.id, isNotEmpty);
      expect(saved.result, EvaluationResult.favorable);
      expect(saved.condition, 8);
      expect(saved.weightG, 2100);
      expect(saved.place, 'Santiago');
    });

    test('RF-PRU-02 · se puede guardar sin definir el resultado', () async {
      await givenPlan(SubscriptionPlan.pro);

      final result = await repository.save(draft());

      expect(result, isA<Ok<Evaluation>>());
      expect((result as Ok<Evaluation>).value.result, EvaluationResult.undefined);
    });

    test('la condición fuera de 1..10 no se guarda', () async {
      await givenPlan(SubscriptionPlan.pro);

      for (final invalid in [0, 11, -3]) {
        final result = await repository.save(draft(condition: invalid));
        expect((result as Err<Evaluation>).failure, isA<ValidationFailure>());
      }

      expect(await repository.save(draft(condition: 10)), isA<Ok<Evaluation>>());
    });

    test('una prueba sin ejemplar no tiene sentido y se rechaza', () async {
      await givenPlan(SubscriptionPlan.pro);

      final result = await repository.save(draft(birdId: ''));

      expect(((result as Err).failure as ValidationFailure).field, 'birdId');
    });

    test('RV-09 · la fecha no puede ser futura', () async {
      await givenPlan(SubscriptionPlan.pro);

      final result = await repository.save(draft(date: now.add(const Duration(days: 1))));

      expect(((result as Err).failure as ValidationFailure).field, 'date');
    });

    test('la prueba se encola para sincronizar', () async {
      await givenPlan(SubscriptionPlan.pro);

      await repository.save(draft());

      final pending = await database.syncQueueDao.pending(maxAttempts: 5);
      expect(pending.single.entityTable, 'evaluations');
    });
  });

  group('RF-PRU-06 · restricción de plan', () {
    test('el plan gratuito no puede registrar pruebas', () async {
      await givenPlan(SubscriptionPlan.free);

      final result = await repository.save(draft());

      expect((result as Err<Evaluation>).failure, isA<PlanLimitFailure>());
      expect(await repository.isAvailableFor(ownerId), isFalse);
    });

    test('Pro y Élite sí', () async {
      for (final plan in [SubscriptionPlan.pro, SubscriptionPlan.elite]) {
        await givenPlan(plan);
        expect(await repository.isAvailableFor(ownerId), isTrue, reason: plan.id);
      }
    });

    test('sin perfil sincronizado se asume el plan más restrictivo', () async {
      expect(await repository.isAvailableFor('desconocido'), isFalse);
    });
  });

  group('RF-PRU-03 · estadísticas del criadero', () {
    test('total, porcentaje favorable y condición promedio', () async {
      await givenPlan(SubscriptionPlan.pro);
      await repository.save(draft(result: EvaluationResult.favorable, condition: 8));
      await repository.save(draft(result: EvaluationResult.favorable, condition: 6));
      await repository.save(draft(result: EvaluationResult.unfavorable, condition: 4));
      await repository.save(draft(result: EvaluationResult.undefined, condition: 2));

      final stats = await repository.watchStats(ownerId).first;

      expect(stats.total, 4);
      expect(stats.favorable, 2);
      // Las pruebas sin definir cuentan en el total: excluirlas inflaría el
      // porcentaje y el criador se llevaría una idea equivocada.
      expect(stats.favorablePercent, 50);
      expect(stats.averageCondition, 5.0);
    });

    test('el promedio ignora las pruebas que no anotaron condición', () async {
      await givenPlan(SubscriptionPlan.pro);
      await repository.save(draft(condition: 10));
      await repository.save(draft());

      final stats = await repository.watchStats(ownerId).first;

      expect(stats.total, 2);
      // Contar la que no la anotó como cero daría 5,0 y sería mentira.
      expect(stats.averageCondition, 10.0);
    });

    test('sin pruebas no hay promedio, y no es cero', () async {
      final stats = await repository.watchStats(ownerId).first;

      expect(stats.total, 0);
      expect(stats.favorablePercent, 0);
      // Cero daría a entender que los ejemplares están en pésimo estado.
      expect(stats.averageCondition, isNull);
    });

    test('una prueba borrada deja de contar', () async {
      await givenPlan(SubscriptionPlan.pro);
      final saved =
          ((await repository.save(draft(result: EvaluationResult.favorable))) as Ok<Evaluation>)
              .value;
      await repository.save(draft(result: EvaluationResult.unfavorable));

      await repository.delete(saved.id);

      final stats = await repository.watchStats(ownerId).first;
      expect(stats.total, 1);
      expect(stats.favorable, 0);
    });
  });

  group('RF-PRU-04 / RF-PRU-05 · listados', () {
    test('filtra el historial por resultado', () async {
      await givenPlan(SubscriptionPlan.pro);
      await repository.save(draft(result: EvaluationResult.favorable));
      await repository.save(draft(result: EvaluationResult.unfavorable));

      final favorable = await repository
          .watchAll(ownerId: ownerId, result: EvaluationResult.favorable)
          .first;

      expect(favorable, hasLength(1));
      expect(await repository.watchAll(ownerId: ownerId).first, hasLength(2));
    });

    test('la ficha de un ejemplar solo muestra sus pruebas', () async {
      await givenPlan(SubscriptionPlan.pro);
      await repository.save(draft(birdId: 'gallo-a'));
      await repository.save(draft(birdId: 'gallo-a'));
      await repository.save(draft(birdId: 'gallo-b'));

      expect(await repository.watchForBird('gallo-a').first, hasLength(2));
      expect(await repository.watchForBird('gallo-b').first, hasLength(1));
    });

    test('el historial va de lo más reciente a lo más antiguo', () async {
      await givenPlan(SubscriptionPlan.pro);
      await repository.save(draft(date: DateTime(2026, 1, 10)));
      await repository.save(draft(date: DateTime(2026, 7, 20)));
      await repository.save(draft(date: DateTime(2026, 4, 5)));

      final all = await repository.watchAll(ownerId: ownerId).first;

      expect(all.map((e) => e.date.month), [7, 4, 1]);
    });
  });
}
