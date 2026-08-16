import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../features/accounting/repository/transactions_repository.dart';
import '../../features/accounting/viewmodel/accounting_viewmodel.dart';
import '../../features/accounting/viewmodel/transaction_form_viewmodel.dart';
import '../../features/auth/model/profile.dart';
import '../../features/auth/repository/auth_preferences.dart';
import '../../features/auth/repository/auth_repository.dart';
import '../../features/auth/repository/profile_repository.dart';
import '../../features/auth/viewmodel/forgot_password_viewmodel.dart';
import '../../features/auth/viewmodel/login_viewmodel.dart';
import '../../features/auth/viewmodel/new_password_viewmodel.dart';
import '../../features/auth/viewmodel/onboarding_viewmodel.dart';
import '../../features/auth/viewmodel/sign_up_viewmodel.dart';
import '../../features/auth/viewmodel/splash_viewmodel.dart';
import '../../features/auth/viewmodel/verify_code_viewmodel.dart';
import '../../features/birds/repository/birds_repository.dart';
import '../../features/birds/repository/clutches_repository.dart';
import '../../features/birds/viewmodel/bird_detail_viewmodel.dart';
import '../../features/birds/viewmodel/bird_form_viewmodel.dart';
import '../../features/birds/viewmodel/birds_list_viewmodel.dart';
import '../../features/birds/viewmodel/clutch_form_viewmodel.dart';
import '../../features/birds/viewmodel/parent_picker_viewmodel.dart';
import '../../features/dashboard/viewmodel/dashboard_viewmodel.dart';
import '../../features/evaluations/repository/evaluations_repository.dart';
import '../../features/evaluations/viewmodel/evaluation_form_viewmodel.dart';
import '../../features/evaluations/viewmodel/evaluations_list_viewmodel.dart';
import '../../features/onboarding/viewmodel/farm_setup_viewmodel.dart';
import '../../features/pedigree/repository/pedigree_repository.dart';
import '../../features/pedigree/viewmodel/pedigree_viewmodel.dart';
import '../../features/settings/viewmodel/app_settings_viewmodel.dart';
import '../../features/settings/viewmodel/settings_viewmodel.dart';
import '../db/app_database.dart';
import '../db/daos/birds_dao.dart';
import '../db/daos/clutches_dao.dart';
import '../db/daos/evaluations_dao.dart';
import '../db/daos/profiles_dao.dart';
import '../db/daos/sync_queue_dao.dart';
import '../db/daos/transactions_dao.dart';
import '../domain/sex.dart';
import '../media/photo_service.dart';
import '../network/connectivity_service.dart';
import '../network/supabase_service.dart';
import '../security/secure_store.dart';
import '../sync/sync_service.dart';

// ---------------------------------------------------------------------------
// Infraestructura. Los dos primeros se sobrescriben en `main()` con instancias
// ya inicializadas, porque su construcción es asíncrona.
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Sobrescribe sharedPreferencesProvider en main()'),
);

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => throw UnimplementedError('Sobrescribe supabaseServiceProvider en main()'),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final birdsDaoProvider = Provider<BirdsDao>((ref) => ref.watch(appDatabaseProvider).birdsDao);
final profilesDaoProvider = Provider<ProfilesDao>(
  (ref) => ref.watch(appDatabaseProvider).profilesDao,
);
final transactionsDaoProvider = Provider<TransactionsDao>(
  (ref) => ref.watch(appDatabaseProvider).transactionsDao,
);
final evaluationsDaoProvider = Provider<EvaluationsDao>(
  (ref) => ref.watch(appDatabaseProvider).evaluationsDao,
);
final clutchesDaoProvider = Provider<ClutchesDao>(
  (ref) => ref.watch(appDatabaseProvider).clutchesDao,
);
final syncQueueDaoProvider = Provider<SyncQueueDao>(
  (ref) => ref.watch(appDatabaseProvider).syncQueueDao,
);

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());

/// Captura y almacenamiento local de fotos — `RF-REG-15`.
final photoServiceProvider = Provider<PhotoService>((ref) => PhotoService());

/// Almacén seguro del sistema — `RNF-14`. Lo construye `main()` porque la
/// clave de la base hace falta antes de que exista el contenedor.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => throw UnimplementedError('Sobrescribe secureStoreProvider en main()'),
);

/// Estado de red para la franja de "sin conexión".
final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).onStatusChange,
);

// ---------------------------------------------------------------------------
// Repositorios
// ---------------------------------------------------------------------------

final birdsRepositoryProvider = Provider<BirdsRepository>(
  (ref) => BirdsRepository(
    database: ref.watch(appDatabaseProvider),
    birdsDao: ref.watch(birdsDaoProvider),
    profilesDao: ref.watch(profilesDaoProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    supabase: ref.watch(supabaseServiceProvider),
  ),
);

final clutchesRepositoryProvider = Provider<ClutchesRepository>(
  (ref) => ClutchesRepository(
    database: ref.watch(appDatabaseProvider),
    clutchesDao: ref.watch(clutchesDaoProvider),
    birdsDao: ref.watch(birdsDaoProvider),
    profilesDao: ref.watch(profilesDaoProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    supabase: ref.watch(supabaseServiceProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    database: ref.watch(appDatabaseProvider),
    profilesDao: ref.watch(profilesDaoProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    supabase: ref.watch(supabaseServiceProvider),
  ),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    queue: ref.watch(syncQueueDaoProvider),
    supabase: ref.watch(supabaseServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    // El perfil primero: el plan condiciona si se pueden crear ejemplares.
    // Las camadas, antes que los ejemplares: las crías las referencian.
    pullers: [
      ref.watch(profileRepositoryProvider),
      ref.watch(clutchesRepositoryProvider),
      ref.watch(birdsRepositoryProvider),
      ref.watch(evaluationsRepositoryProvider),
      ref.watch(transactionsRepositoryProvider),
    ],
  );
  ref.onDispose(service.dispose);
  return service;
});

final authPreferencesProvider = Provider<AuthPreferences>(
  (ref) => AuthPreferences(ref.watch(sharedPreferencesProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    supabase: ref.watch(supabaseServiceProvider),
    profilesDao: ref.watch(profilesDaoProvider),
    birdsDao: ref.watch(birdsDaoProvider),
    clutchesDao: ref.watch(clutchesDaoProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    syncService: ref.watch(syncServiceProvider),
    preferences: ref.watch(authPreferencesProvider),
  ),
);

// ---------------------------------------------------------------------------
// Sesión
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// Id del criadero actual. Cadena vacía si no hay sesión: las consultas no
/// devuelven nada y evitamos que la UI reviente durante el cierre de sesión,
/// justo antes de que el router redirija al login.
final currentOwnerIdProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseServiceProvider).currentUserId ?? '';
});

/// Perfil del usuario en sesión, observado desde Drift.
///
/// Vale `null` mientras no hay sesión o el perfil todavía no ha bajado. La
/// guardia del router lo consulta para decidir si toca la configuración
/// inicial, así que distinguir «no hay» de «aún no sé» importa: con `null` no
/// se mueve al usuario de sitio.
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  final ownerId = ref.watch(currentOwnerIdProvider);
  if (ownerId.isEmpty) return Stream<Profile?>.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(ownerId);
});

// ---------------------------------------------------------------------------
// ViewModels
// ---------------------------------------------------------------------------

final appSettingsProvider = ChangeNotifierProvider<AppSettingsViewModel>(
  (ref) => AppSettingsViewModel(ref.watch(sharedPreferencesProvider)),
);

// --- Entrada y autenticación (RF-AUT) --------------------------------------

final splashViewModelProvider = Provider.autoDispose<SplashViewModel>(
  (ref) => SplashViewModel(
    auth: ref.watch(authRepositoryProvider),
    preferences: ref.watch(authPreferencesProvider),
  ),
);

final onboardingViewModelProvider = ChangeNotifierProvider.autoDispose<OnboardingViewModel>(
  (ref) => OnboardingViewModel(ref.watch(authPreferencesProvider)),
);

final loginViewModelProvider = ChangeNotifierProvider.autoDispose<LoginViewModel>(
  (ref) => LoginViewModel(
    auth: ref.watch(authRepositoryProvider),
    preferences: ref.watch(authPreferencesProvider),
  ),
);

final signUpViewModelProvider = ChangeNotifierProvider.autoDispose<SignUpViewModel>(
  (ref) => SignUpViewModel(ref.watch(authRepositoryProvider)),
);

/// `family` por correo y propósito: la pantalla de verificación del alta y la
/// de la recuperación son la misma vista, pero no comparten cuenta regresiva.
final verifyCodeViewModelProvider = ChangeNotifierProvider.autoDispose
    .family<VerifyCodeViewModel, VerifyCodeArgs>(
      (ref, args) => VerifyCodeViewModel(
        auth: ref.watch(authRepositoryProvider),
        email: args.email,
        purpose: args.purpose,
      ),
    );

final forgotPasswordViewModelProvider = ChangeNotifierProvider.autoDispose<ForgotPasswordViewModel>(
  (ref) => ForgotPasswordViewModel(ref.watch(authRepositoryProvider)),
);

final newPasswordViewModelProvider = ChangeNotifierProvider.autoDispose<NewPasswordViewModel>(
  (ref) => NewPasswordViewModel(ref.watch(authRepositoryProvider)),
);

// --- Configuración inicial (RF-ONB) ----------------------------------------

/// Sin `autoDispose`: los tres pasos son pantallas del mismo formulario y
/// perder lo escrito al volver atrás rompería `RF-ONB-07`.
final farmSetupViewModelProvider = ChangeNotifierProvider<FarmSetupViewModel>(
  (ref) => FarmSetupViewModel(
    profiles: ref.watch(profileRepositoryProvider),
    ownerId: ref.watch(currentOwnerIdProvider),
  ),
);

final dashboardViewModelProvider = ChangeNotifierProvider.autoDispose<DashboardViewModel>(
  (ref) => DashboardViewModel(
    birds: ref.watch(birdsRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    clutches: ref.watch(clutchesDaoProvider),
    sync: ref.watch(syncServiceProvider),
    ownerId: ref.watch(currentOwnerIdProvider),
  ),
);

final birdsListViewModelProvider = ChangeNotifierProvider.autoDispose<BirdsListViewModel>(
  (ref) => BirdsListViewModel(
    repository: ref.watch(birdsRepositoryProvider),
    ownerId: ref.watch(currentOwnerIdProvider),
  ),
);

/// `null` = alta; con id = edición.
final birdFormViewModelProvider = ChangeNotifierProvider.autoDispose
    .family<BirdFormViewModel, String?>(
      (ref, birdId) => BirdFormViewModel(
        repository: ref.watch(birdsRepositoryProvider),
        photoService: ref.watch(photoServiceProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
        birdId: birdId,
      ),
    );

final clutchFormViewModelProvider = ChangeNotifierProvider.autoDispose<ClutchFormViewModel>(
  (ref) => ClutchFormViewModel(
    repository: ref.watch(clutchesRepositoryProvider),
    ownerId: ref.watch(currentOwnerIdProvider),
  ),
);

/// Pantalla 18 — `RF-REG-11`. El sexo y el ejemplar a excluir identifican la
/// instancia: elegir padre y elegir madre son dos listas distintas.
typedef ParentPickerArgs = ({Sex sex, String? excludeId});

final parentPickerViewModelProvider = ChangeNotifierProvider.autoDispose
    .family<ParentPickerViewModel, ParentPickerArgs>(
      (ref, args) => ParentPickerViewModel(
        repository: ref.watch(birdsRepositoryProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
        sex: args.sex,
        excludeId: args.excludeId,
      ),
    );

final birdDetailViewModelProvider = ChangeNotifierProvider.autoDispose
    .family<BirdDetailViewModel, String>(
      (ref, birdId) => BirdDetailViewModel(
        repository: ref.watch(birdsRepositoryProvider),
        clutchesRepository: ref.watch(clutchesRepositoryProvider),
        evaluationsRepository: ref.watch(evaluationsRepositoryProvider),
        pedigreeRepository: ref.watch(pedigreeRepositoryProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
        birdId: birdId,
      ),
    );

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(
    database: ref.watch(appDatabaseProvider),
    transactionsDao: ref.watch(transactionsDaoProvider),
    profilesDao: ref.watch(profilesDaoProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    supabase: ref.watch(supabaseServiceProvider),
  ),
);

final accountingViewModelProvider = ChangeNotifierProvider.autoDispose<AccountingViewModel>(
  (ref) => AccountingViewModel(
    repository: ref.watch(transactionsRepositoryProvider),
    ownerId: ref.watch(currentOwnerIdProvider),
  ),
);

final transactionFormViewModelProvider =
    ChangeNotifierProvider.autoDispose<TransactionFormViewModel>(
      (ref) => TransactionFormViewModel(
        repository: ref.watch(transactionsRepositoryProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
      ),
    );

final evaluationsRepositoryProvider = Provider<EvaluationsRepository>(
  (ref) => EvaluationsRepository(
    database: ref.watch(appDatabaseProvider),
    evaluationsDao: ref.watch(evaluationsDaoProvider),
    profilesDao: ref.watch(profilesDaoProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    supabase: ref.watch(supabaseServiceProvider),
  ),
);

final evaluationsListViewModelProvider =
    ChangeNotifierProvider.autoDispose<EvaluationsListViewModel>(
      (ref) => EvaluationsListViewModel(
        repository: ref.watch(evaluationsRepositoryProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
      ),
    );

/// `null` abre el selector de ejemplar; con id viene ya elegido desde la ficha.
final evaluationFormViewModelProvider = ChangeNotifierProvider.autoDispose
    .family<EvaluationFormViewModel, String?>(
      (ref, birdId) => EvaluationFormViewModel(
        repository: ref.watch(evaluationsRepositoryProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
        birdId: birdId,
      ),
    );

final pedigreeRepositoryProvider = Provider<PedigreeRepository>(
  (ref) => PedigreeRepository(birdsDao: ref.watch(birdsDaoProvider)),
);

/// Pantalla 23 — `RF-PED`. Uno por ejemplar: abrir el pedigrí de un ancestro
/// desde un nodo no debe pisar el árbol desde el que se llegó.
final pedigreeViewModelProvider = ChangeNotifierProvider.autoDispose
    .family<PedigreeViewModel, String>(
      (ref, birdId) => PedigreeViewModel(
        repository: ref.watch(pedigreeRepositoryProvider),
        profilesDao: ref.watch(profilesDaoProvider),
        ownerId: ref.watch(currentOwnerIdProvider),
        birdId: birdId,
      ),
    );

final settingsViewModelProvider = ChangeNotifierProvider.autoDispose<SettingsViewModel>(
  (ref) => SettingsViewModel(
    auth: ref.watch(authRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    birds: ref.watch(birdsRepositoryProvider),
    sync: ref.watch(syncServiceProvider),
    ownerId: ref.watch(currentOwnerIdProvider),
  ),
);
