import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/network/connectivity_service.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/sync/sync_service.dart';
import 'package:criadorpro/features/auth/repository/auth_preferences.dart';
import 'package:criadorpro/features/auth/repository/auth_repository.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `RF-AUT-15` — cerrar sesión conserva los datos locales.
///
/// Antes se borraba todo, y era lo correcto mientras la base estaba en claro.
/// Con `RNF-15` cumplido esa razón desaparece, pero aparece otra obligación:
/// si en el mismo teléfono entra **otro** criadero, el libro del anterior tiene
/// que desaparecer.
void main() {
  late AppDatabase database;
  late AuthRepository repository;
  late AuthPreferences preferences;

  final now = DateTime(2026, 8, 5);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    preferences = AuthPreferences(await SharedPreferences.getInstance());

    final supabase = SupabaseService(null);
    repository = AuthRepository(
      supabase: supabase,
      profilesDao: database.profilesDao,
      birdsDao: database.birdsDao,
      clutchesDao: database.clutchesDao,
      evaluationsDao: database.evaluationsDao,
      transactionsDao: database.transactionsDao,
      payrollDao: database.payrollDao,
      syncQueue: database.syncQueueDao,
      syncService: SyncService(
        queue: database.syncQueueDao,
        supabase: supabase,
        connectivity: ConnectivityService(),
        preferences: await SharedPreferences.getInstance(),
        pullers: const [],
      ),
      preferences: preferences,
    );
  });

  tearDown(() => database.close());

  Future<void> givenLocalData({String ownerId = 'criador-1'}) async {
    await database.birdsDao.upsert(
      BirdsCompanion.insert(
        id: 'b1',
        ownerId: ownerId,
        plate: 1,
        sex: Sex.male.id,
        status: BirdStatus.active.id,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.clutchesDao.upsert(
      ClutchesCompanion.insert(
        id: 'c1',
        ownerId: ownerId,
        date: now,
        hatched: 3,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.profilesDao.upsert(
      ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now),
    );
  }

  Future<int> countBirds() => database.birdsDao.countForOwner('criador-1');
  Future<int> countClutches() => database.clutchesDao.watchCountForOwner('criador-1').first;

  test('cerrar sesión conserva ejemplares, camadas y perfil', () async {
    await givenLocalData();

    await repository.signOut();

    // El criador vuelve a entrar y su libro sigue ahí: sin esto, cada cierre
    // de sesión obligaría a una descarga completa en medio del galpón.
    expect(await countBirds(), 1);
    expect(await countClutches(), 1);
    expect(await database.profilesDao.findById('criador-1'), isNotNull);
  });

  test('el mismo criadero al volver conserva sus datos', () async {
    await givenLocalData();
    await repository.adoptSession('criador-1');

    await repository.signOut();
    await repository.adoptSession('criador-1');

    expect(await countBirds(), 1);
    expect(await countClutches(), 1);
  });

  test('otro criadero en el mismo teléfono no hereda el libro anterior', () async {
    await givenLocalData();
    await repository.adoptSession('criador-1');
    await repository.signOut();

    await repository.adoptSession('criador-2');

    expect(await countBirds(), 0);
    expect(await countClutches(), 0);
    expect(await database.profilesDao.findById('criador-1'), isNull);
  });

  test('las camadas también se borran al cambiar de criadero', () async {
    // Antes de `RF-AUT-15`, `signOut` borraba ejemplares, perfil y cola pero
    // **no camadas**: quedaban en el dispositivo del siguiente usuario.
    await givenLocalData();
    await repository.adoptSession('criador-1');

    await repository.adoptSession('otro');

    expect(await countClutches(), 0);
  });

  test('la primera entrada en un dispositivo nuevo no borra nada', () async {
    // Sin criadero anterior registrado no hay nada que proteger, y borrar aquí
    // tiraría lo que la sincronización acabe de bajar.
    await givenLocalData();

    await repository.adoptSession('criador-1');

    expect(await countBirds(), 1);
    expect(preferences.lastOwnerId, 'criador-1');
  });
}
