import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/evaluations/model/evaluation.dart';
import 'package:criadorpro/features/evaluations/repository/evaluations_repository.dart';
import 'package:criadorpro/features/evaluations/viewmodel/evaluation_form_viewmodel.dart';
import 'package:criadorpro/features/evaluations/viewmodel/evaluations_list_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
// `flutter_test` exporta su propia `Evaluation` (la de accesibilidad).
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

void main() {
  late AppDatabase database;
  late EvaluationsRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5, 16);

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

  Bird bird(String id) => Bird(
    id: id,
    ownerId: ownerId,
    plate: 40,
    sex: Sex.male,
    status: BirdStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  group('EvaluationFormViewModel · pantalla 25', () {
    EvaluationFormViewModel formFor({String? birdId}) => EvaluationFormViewModel(
      repository: repository,
      ownerId: ownerId,
      birdId: birdId,
      clock: () => now,
    );

    test('arranca con la fecha de hoy, sin hora', () async {
      final viewModel = formFor();

      await viewModel.load();

      expect(viewModel.date, DateTime(2026, 8, 5));
      expect(viewModel.isDateInFuture, isFalse);
      viewModel.dispose();
    });

    test('sin ejemplar no se puede enviar', () async {
      final viewModel = formFor();
      await viewModel.load();

      expect(viewModel.canSubmit, isFalse);

      viewModel.setBird(bird('gallo-1'));
      expect(viewModel.canSubmit, isTrue);
      viewModel.dispose();
    });

    test('abierta desde la ficha, el ejemplar viene fijo', () async {
      final viewModel = formFor(birdId: 'desde-ficha');
      await viewModel.load();

      expect(viewModel.birdId, 'desde-ficha');
      expect(viewModel.isBirdLocked, isTrue);
      expect(viewModel.canSubmit, isTrue);
      viewModel.dispose();
    });

    test('RF-PRU-02 · se envía sin resultado definido', () async {
      await givenPlan(SubscriptionPlan.pro);
      final viewModel = formFor(birdId: 'gallo-1');
      await viewModel.load();

      final saved = await viewModel.submit();

      expect(saved, isNotNull);
      expect(saved!.result, EvaluationResult.undefined);
      viewModel.dispose();
    });

    test('tocar dos veces la misma condición la retira', () async {
      final viewModel = formFor(birdId: 'gallo-1');
      await viewModel.load();

      viewModel.setCondition(7);
      expect(viewModel.condition, 7);

      // Es opcional: sin esto no habría forma de deshacer un toque accidental.
      viewModel.setCondition(7);
      expect(viewModel.condition, isNull);
      viewModel.dispose();
    });

    test('una fecha futura bloquea el envío', () async {
      final viewModel = formFor(birdId: 'gallo-1');
      await viewModel.load();

      viewModel.setDate(DateTime(2026, 8, 6));

      expect(viewModel.isDateInFuture, isTrue);
      expect(viewModel.canSubmit, isFalse);
      viewModel.dispose();
    });

    test('RF-PRU-06 · el plan gratuito recibe el fallo al enviar', () async {
      await givenPlan(SubscriptionPlan.free);
      final viewModel = formFor(birdId: 'gallo-1');
      await viewModel.load();

      final saved = await viewModel.submit();

      expect(saved, isNull);
      expect(viewModel.failure, isNotNull);
      viewModel.dispose();
    });
  });

  group('EvaluationsListViewModel · pantalla 24', () {
    Future<EvaluationsListViewModel> listViewModel() async {
      final viewModel = EvaluationsListViewModel(repository: repository, ownerId: ownerId);
      await viewModel.load();
      return viewModel;
    }

    Future<void> givenEvaluation(EvaluationResult result, {int? condition}) => repository.save(
      Evaluation(
        id: '',
        ownerId: ownerId,
        birdId: 'gallo-1',
        date: DateTime(2026, 8, 1),
        result: result,
        condition: condition,
        createdAt: now,
        updatedAt: now,
      ),
    );

    test('RF-PRU-06 · con plan gratuito el módulo se marca no disponible', () async {
      await givenPlan(SubscriptionPlan.free);

      final viewModel = await listViewModel();

      // No se oculta: la pantalla se muestra con su aviso.
      expect(viewModel.isAvailable, isFalse);
      viewModel.dispose();
    });

    test('con Pro está disponible', () async {
      await givenPlan(SubscriptionPlan.pro);

      final viewModel = await listViewModel();

      expect(viewModel.isAvailable, isTrue);
      viewModel.dispose();
    });

    test('RF-PRU-04 · el filtro cambia la lista pero no las estadísticas', () async {
      await givenPlan(SubscriptionPlan.pro);
      await givenEvaluation(EvaluationResult.favorable, condition: 8);
      await givenEvaluation(EvaluationResult.unfavorable, condition: 4);

      final viewModel = await listViewModel();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(viewModel.evaluations, hasLength(2));
      expect(viewModel.stats.total, 2);

      viewModel.setFilter(EvaluationResult.favorable);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(viewModel.evaluations, hasLength(1));
      // `RF-PRU-03` pide el resumen **del criadero**, no el del filtro puesto.
      expect(viewModel.stats.total, 2);
      expect(viewModel.stats.favorablePercent, 50);
      viewModel.dispose();
    });
  });
}
