import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/network/connectivity_service.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/sync/sync_service.dart';
import 'package:criadorpro/features/auth/repository/profile_repository.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
import 'package:criadorpro/features/dashboard/viewmodel/dashboard_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `RF-REG-01`, `RF-REG-02` y `RF-REG-16` — los conteos de Inicio y el aviso de
/// capacidad del plan.
void main() {
  late AppDatabase database;
  late DashboardViewModel viewModel;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 6);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    database = AppDatabase(NativeDatabase.memory());
    viewModel = DashboardViewModel(
      birds: BirdsRepository(
        database: database,
        birdsDao: database.birdsDao,
        profilesDao: database.profilesDao,
        syncQueue: database.syncQueueDao,
        supabase: SupabaseService(null),
        clock: () => now,
      ),
      profiles: ProfileRepository(
        database: database,
        profilesDao: database.profilesDao,
        syncQueue: database.syncQueueDao,
        supabase: SupabaseService(null),
        clock: () => now,
      ),
      clutches: database.clutchesDao,
      // Sin backend, `SyncService` no hace nada: estas pruebas solo necesitan
      // que el ViewModel pueda suscribirse a sus streams.
      sync: SyncService(
        queue: database.syncQueueDao,
        supabase: SupabaseService(null),
        connectivity: ConnectivityService(),
        preferences: preferences,
        pullers: const [],
      ),
      ownerId: ownerId,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  Future<void> givenProfile(SubscriptionPlan plan) => database.profilesDao.upsert(
    ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now, plan: Value(plan.id)),
  );

  Future<void> givenBirds(int count, {BirdStatus status = BirdStatus.active}) async {
    for (var index = 0; index < count; index++) {
      await database.birdsDao.upsert(
        BirdsCompanion.insert(
          id: 'bird-$index',
          ownerId: ownerId,
          plate: index + 1,
          sex: index.isEven ? Sex.male.id : Sex.female.id,
          status: status.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  /// Los streams de Drift emiten en el siguiente microtask.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('RF-REG-01 · conteos', () {
    test('separa machos y hembras', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(5);
      await settle();

      expect(viewModel.total, 5);
      expect(viewModel.males, 3);
      expect(viewModel.females, 2);
    });
  });

  group('PRD pantalla 15 · encabezado y cuarto contador', () {
    test('el encabezado muestra el nombre del criadero', () async {
      await database.profilesDao.upsert(
        ProfilesCompanion.insert(
          id: ownerId,
          createdAt: now,
          updatedAt: now,
          farmName: const Value('Criadero Los Pinos'),
        ),
      );
      await settle();

      expect(viewModel.farmName, 'Criadero Los Pinos');
    });

    test(
      'sin perfil todavía, el encabezado queda vacío y la vista cae al nombre del producto',
      () async {
        await settle();

        expect(viewModel.farmName, isEmpty);
      },
    );

    test('RF-REG-01 · el cuarto contador son las camadas', () async {
      await givenProfile(SubscriptionPlan.free);
      for (var index = 0; index < 3; index++) {
        await database.clutchesDao.upsert(
          ClutchesCompanion.insert(
            id: 'clutch-$index',
            ownerId: ownerId,
            date: now,
            hatched: 5,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await settle();

      expect(viewModel.clutches, 3);
    });

    test('una camada borrada deja de contar', () async {
      await givenProfile(SubscriptionPlan.free);
      await database.clutchesDao.upsert(
        ClutchesCompanion.insert(
          id: 'clutch-0',
          ownerId: ownerId,
          date: now,
          hatched: 5,
          createdAt: now,
          updatedAt: now,
          isDeleted: const Value(true),
        ),
      );
      await settle();

      expect(viewModel.clutches, 0);
    });
  });

  group('RF-REG-02 · aviso al 80 % del plan', () {
    test('no avisa por debajo del umbral', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(19); // 76 % de 25
      await settle();

      expect(viewModel.isNearPlanLimit, isFalse);
      expect(viewModel.isAtPlanLimit, isFalse);
    });

    test('avisa justo al alcanzarlo', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(20); // 80 % de 25
      await settle();

      expect(viewModel.isNearPlanLimit, isTrue);
      expect(viewModel.isAtPlanLimit, isFalse);
    });

    test('al llegar al tope deja de ser aviso y pasa a bloqueo', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(25);
      await settle();

      expect(viewModel.isNearPlanLimit, isFalse);
      expect(viewModel.isAtPlanLimit, isTrue);
    });

    test('el plan Élite no avisa nunca: no tiene tope', () async {
      await givenProfile(SubscriptionPlan.elite);
      await givenBirds(600);
      await settle();

      expect(viewModel.planLimit, isNull);
      expect(viewModel.isNearPlanLimit, isFalse);
      expect(viewModel.isAtPlanLimit, isFalse);
    });

    test('RS-02 · los ejemplares vendidos no cuentan para el límite', () async {
      await givenProfile(SubscriptionPlan.free);
      await givenBirds(25, status: BirdStatus.sold);
      await settle();

      expect(viewModel.activeCount, 0);
      expect(viewModel.isAtPlanLimit, isFalse);
    });
  });
}
