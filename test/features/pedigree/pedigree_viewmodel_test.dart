import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/pedigree/repository/pedigree_repository.dart';
import 'package:criadorpro/features/pedigree/viewmodel/pedigree_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-PED-02` y `RF-PED-03`: el selector de profundidad y el tope del plan.
void main() {
  late AppDatabase database;
  late PedigreeRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = PedigreeRepository(birdsDao: database.birdsDao);

    // Árbol completo de cuatro generaciones.
    const total = 31;
    for (var i = total; i >= 1; i--) {
      final father = i * 2;
      final mother = i * 2 + 1;
      await database.birdsDao.upsert(
        BirdsCompanion.insert(
          id: 'b$i',
          ownerId: ownerId,
          plate: i,
          sex: (i.isEven || i == 1 ? Sex.male : Sex.female).id,
          status: BirdStatus.active.id,
          createdAt: now,
          updatedAt: now,
          fatherId: Value(father <= total ? 'b$father' : null),
          motherId: Value(mother <= total ? 'b$mother' : null),
        ),
      );
    }
  });

  tearDown(() => database.close());

  Future<PedigreeViewModel> viewModelFor(SubscriptionPlan plan) async {
    await database.profilesDao.upsert(
      ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now, plan: Value(plan.id)),
    );
    return PedigreeViewModel(
      repository: repository,
      profilesDao: database.profilesDao,
      ownerId: ownerId,
      birdId: 'b1',
    );
  }

  group('RF-PED-03 · tope por plan', () {
    test('el plan gratuito se queda en dos generaciones', () async {
      final viewModel = await viewModelFor(SubscriptionPlan.free);

      await viewModel.load();

      expect(viewModel.allowedDepth, 2);
      // Arranca ya en el máximo permitido: el selector no debe ofrecer una
      // vista que luego se recorta.
      expect(viewModel.depth, 2);
      expect(viewModel.root!.size, 7);
      expect(viewModel.isLimitedByPlan, isTrue);
      viewModel.dispose();
    });

    test('Pro y Élite llegan a cuatro', () async {
      for (final plan in [SubscriptionPlan.pro, SubscriptionPlan.elite]) {
        final viewModel = await viewModelFor(plan);
        await viewModel.load();

        expect(viewModel.allowedDepth, 4, reason: plan.id);
        expect(viewModel.depth, 4);
        expect(viewModel.root!.size, 31);
        expect(viewModel.isLimitedByPlan, isFalse);
        viewModel.dispose();
      }
    });

    test('el plan gratuito no puede saltarse el tope desde el selector', () async {
      final viewModel = await viewModelFor(SubscriptionPlan.free);
      await viewModel.load();

      await viewModel.setDepth(4);

      expect(viewModel.depth, 2);
      expect(viewModel.root!.size, 7);
      expect(viewModel.isDepthAvailable(3), isFalse);
      expect(viewModel.isDepthAvailable(4), isFalse);
      viewModel.dispose();
    });

    test('sin perfil sincronizado se asume el plan más restrictivo', () async {
      // Dispositivo nuevo antes de la primera bajada: mejor quedarse corto que
      // enseñar cuatro generaciones y retirarlas después.
      final viewModel = PedigreeViewModel(
        repository: repository,
        profilesDao: database.profilesDao,
        ownerId: 'sin-perfil',
        birdId: 'b1',
      );

      await viewModel.load();

      expect(viewModel.allowedDepth, 2);
      viewModel.dispose();
    });
  });

  group('RF-PED-02 · cambiar de profundidad', () {
    test('reconstruye el árbol al cambiar', () async {
      final viewModel = await viewModelFor(SubscriptionPlan.pro);
      await viewModel.load();
      expect(viewModel.root!.size, 31);

      await viewModel.setDepth(2);
      expect(viewModel.depth, 2);
      expect(viewModel.root!.size, 7);

      await viewModel.setDepth(3);
      expect(viewModel.root!.size, 15);
      viewModel.dispose();
    });

    test('elegir la profundidad ya activa no reconstruye', () async {
      final viewModel = await viewModelFor(SubscriptionPlan.pro);
      await viewModel.load();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.setDepth(4);

      expect(notifications, 0);
      viewModel.dispose();
    });
  });
}
