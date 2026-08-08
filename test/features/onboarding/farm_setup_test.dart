import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/validators.dart';
import 'package:criadorpro/features/auth/model/profile.dart';
import 'package:criadorpro/features/auth/repository/profile_repository.dart';
import 'package:criadorpro/features/onboarding/viewmodel/farm_setup_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProfileRepository profiles;
  late FarmSetupViewModel viewModel;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    profiles = ProfileRepository(
      database: database,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
    viewModel = FarmSetupViewModel(profiles: profiles, ownerId: ownerId);

    // El perfil ya existe: lo crea el trigger al registrarse.
    await database.profilesDao.upsert(
      ProfilesCompanion.insert(
        id: ownerId,
        createdAt: now,
        updatedAt: now,
        fullName: const Value('Ramón Peña'),
      ),
    );
  });

  tearDown(() => database.close());

  void fillValidSetup() {
    viewModel
      ..setFarmName('Criadero Los Pinos')
      ..setLocation('Santiago')
      ..setPlate('1687');
  }

  group('RV-06 · nombre del criadero', () {
    test('acepta entre 2 y 60 caracteres', () {
      expect(Validators.farmName('Los Pinos'), isNull);
    });

    test('rechaza vacío: es el único campo obligatorio de la pantalla 11', () {
      expect(Validators.farmName('   '), ValidationError.required);
    });

    test('rechaza fuera de rango', () {
      expect(Validators.farmName('A'), ValidationError.farmNameLength);
      expect(Validators.farmName('a' * 61), ValidationError.farmNameLength);
    });
  });

  group('RV-07 · placa inicial', () {
    test('acepta de 1 a 999.999', () {
      expect(Validators.initialPlate('1'), isNull);
      expect(Validators.initialPlate('999999'), isNull);
    });

    test('rechaza cero, negativos y lo que pase del máximo', () {
      expect(Validators.initialPlate('0'), ValidationError.plateOutOfRange);
      expect(Validators.initialPlate('-3'), ValidationError.plateOutOfRange);
      expect(Validators.initialPlate('1000000'), ValidationError.plateOutOfRange);
    });

    test('rechaza lo que no sea un número', () {
      expect(Validators.initialPlate('mil'), ValidationError.notANumber);
    });
  });

  group('pasos', () {
    test('no avanza sin nombre de criadero', () {
      expect(viewModel.next(), isFalse);
      expect(viewModel.step, FarmSetupStep.profile);
      expect(viewModel.farmNameError, ValidationError.required);
    });

    test('avanza a numeración con el nombre puesto', () {
      viewModel.setFarmName('Criadero Los Pinos');

      expect(viewModel.next(), isTrue);
      expect(viewModel.step, FarmSetupStep.numbering);
    });

    test('no avanza con una placa fuera de rango', () {
      viewModel
        ..setFarmName('Criadero Los Pinos')
        ..next()
        ..setPlate('0');

      expect(viewModel.next(), isFalse);
      expect(viewModel.step, FarmSetupStep.numbering);
    });

    test('RF-ONB-07 · volver atrás conserva lo escrito', () {
      fillValidSetup();
      viewModel
        ..next()
        ..next();
      expect(viewModel.step, FarmSetupStep.plan);

      viewModel.back();
      expect(viewModel.step, FarmSetupStep.numbering);
      viewModel.back();
      expect(viewModel.step, FarmSetupStep.profile);
      // El nombre sigue ahí: no se ha perdido al retroceder.
      expect(viewModel.farmName, 'Criadero Los Pinos');
    });

    test('el primer paso no tiene vuelta atrás', () {
      viewModel.back();
      expect(viewModel.step, FarmSetupStep.profile);
    });
  });

  group('cierre de la configuración', () {
    test('RF-ONB-03 · la numeración continúa en la placa siguiente', () async {
      fillValidSetup();

      expect(await viewModel.submit(locale: 'es'), isTrue);

      final saved = await database.profilesDao.findById(ownerId);
      // Declaró 1687, así que el próximo ejemplar será el 1688.
      expect(saved!.nextPlate, 1688);
      expect(saved.farmName, 'Criadero Los Pinos');
      expect(saved.location, 'Santiago');
    });

    test('RF-ONB-01 · la ubicación es opcional', () async {
      viewModel
        ..setFarmName('Criadero Los Pinos')
        ..setPlate('1');

      expect(await viewModel.submit(locale: 'es'), isTrue);
      expect((await database.profilesDao.findById(ownerId))!.location, isNull);
    });

    test('el criadero completado desbloquea la app', () async {
      final before = Profile.fromRow((await database.profilesDao.findById(ownerId))!);
      expect(before.isOnboardingComplete, isFalse);

      fillValidSetup();
      await viewModel.submit(locale: 'es');

      final after = Profile.fromRow((await database.profilesDao.findById(ownerId))!);
      expect(after.isOnboardingComplete, isTrue);
    });

    test('encola el cambio para sincronizar, con next_plate incluido', () async {
      fillValidSetup();
      await viewModel.submit(locale: 'es');

      final pending = await database.syncQueueDao.pending(maxAttempts: AppConfig.maxSyncAttempts);
      expect(pending, hasLength(1));
      expect(pending.single.entityTable, 'profiles');
      // `toRemoteJson()` lo omite a propósito; el onboarding es la excepción.
      expect(pending.single.payload, contains('"next_plate":1688'));
    });

    test('no guarda nada si algún campo es inválido', () async {
      viewModel
        ..setFarmName('X')
        ..setPlate('1');

      expect(await viewModel.submit(locale: 'es'), isFalse);
      expect((await database.profilesDao.findById(ownerId))!.farmName, isNull);
    });

    test('guarda el idioma con el que se está usando la app', () async {
      fillValidSetup();
      await viewModel.submit(locale: 'en');

      expect((await database.profilesDao.findById(ownerId))!.locale, 'en');
    });

    test('un idioma no admitido cae al español en vez de romper el CHECK', () async {
      fillValidSetup();
      await viewModel.submit(locale: 'fr');

      expect((await database.profilesDao.findById(ownerId))!.locale, AppConfig.defaultLocale);
    });
  });
}
