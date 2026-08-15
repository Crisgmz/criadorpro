import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/repository/auth_repository.dart';
import '../../features/auth/view/forgot_password_view.dart';
import '../../features/auth/view/login_view.dart';
import '../../features/auth/view/new_password_view.dart';
import '../../features/auth/view/onboarding_view.dart';
import '../../features/auth/view/sign_up_view.dart';
import '../../features/auth/view/splash_view.dart';
import '../../features/auth/view/verify_code_view.dart';
import '../../features/auth/view/welcome_view.dart';
import '../../features/birds/view/bird_detail_view.dart';
import '../../features/birds/view/bird_form_view.dart';
import '../../features/birds/view/birds_list_view.dart';
import '../../features/birds/view/clutch_form_view.dart';
import '../../features/birds/view/parent_picker_view.dart';
import '../../features/dashboard/view/dashboard_shell.dart';
import '../../features/dashboard/view/dashboard_view.dart';
import '../../features/evaluations/view/evaluation_form_view.dart';
import '../../features/evaluations/view/evaluations_list_view.dart';
import '../../features/onboarding/view/farm_setup_view.dart';
import '../../features/onboarding/view/setup_done_view.dart';
import '../../features/pedigree/view/pedigree_view.dart';
import '../../features/settings/view/settings_view.dart';
import '../domain/sex.dart';
import '../providers/providers.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _RouterRefreshNotifier();
  ref.onDispose(refresh.dispose);

  // Dos cosas mueven al usuario de sitio: abrir o cerrar sesión, y terminar la
  // configuración inicial. El router tiene que reevaluar sus guardias con
  // ambas.
  ref
    ..listen(authStateProvider, (_, _) => refresh.ping())
    ..listen(currentProfileProvider, (_, _) => refresh.ping());

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // La pantalla de entrada decide su propio destino tras dos segundos
      // (`RF-AUT-01`), así que aquí se la deja pasar.
      if (path == Routes.splash) return null;

      // El flujo de recuperación se autogestiona: verificar el código abre
      // sesión, y sin esta excepción el usuario saldría disparado a Inicio
      // justo antes de poder escribir su contraseña nueva.
      if (Routes.isRecoveryFlow(path)) return null;

      final isPublic = Routes.isPublic(path);
      if (!auth.isSignedIn) return isPublic ? null : Routes.welcome;

      // `null` no significa «sin perfil», sino «todavía no ha bajado». Mover al
      // usuario con esa duda lo mandaría a configurar un criadero que quizá ya
      // tiene; cuando el perfil llegue, este redirect se vuelve a evaluar.
      final profile = ref.read(currentProfileProvider).valueOrNull;

      // La celebración se muestra justo después de guardar, cuando el criadero
      // ya tiene nombre. Sin esta excepción la regla de abajo la saltaría hacia
      // Inicio y la pantalla 14 no llegaría a verse nunca.
      if (path == Routes.onboardingDone) return null;

      final isSetup = Routes.isFarmSetup(path);

      if (profile != null && !profile.isOnboardingComplete) {
        // `RF-ONB`: sin nombre de criadero no se entra a ninguna otra pantalla.
        return isSetup ? null : Routes.farmSetup;
      }
      // Con la configuración hecha, volver al onboarding no tiene sentido.
      if (isSetup && profile != null) return Routes.home;

      return isPublic ? Routes.home : null;
    },
    routes: [
      // --- Entrada y autenticación (pantallas 1–10) ------------------------
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashView()),
      GoRoute(path: Routes.onboarding, builder: (context, state) => const OnboardingView()),
      GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeView()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginView()),

      // `/signup/verify` se declara antes que `/signup` para que gane el path
      // completo y no se interprete «verify» como parte del alta.
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, state) => VerifyCodeView(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: VerificationPurpose.signUp,
        ),
      ),
      GoRoute(path: Routes.signUp, builder: (context, state) => const SignUpView()),

      GoRoute(
        path: Routes.recoverCode,
        builder: (context, state) => VerifyCodeView(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: VerificationPurpose.passwordRecovery,
        ),
      ),
      GoRoute(path: Routes.recoverPassword, builder: (context, state) => const NewPasswordView()),
      GoRoute(path: Routes.recover, builder: (context, state) => const ForgotPasswordView()),

      // --- Configuración inicial (pantallas 11–14) -------------------------
      GoRoute(path: Routes.farmSetup, builder: (context, state) => const FarmSetupView()),
      GoRoute(path: Routes.onboardingDone, builder: (context, state) => const SetupDoneView()),

      // --- Pestañas principales --------------------------------------------
      // Comparten shell, barra inferior y aviso sin conexión.
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (context, state) => const DashboardView()),
          GoRoute(path: Routes.birds, builder: (context, state) => const BirdsListView()),
          GoRoute(
            path: Routes.evaluations,
            builder: (context, state) => const EvaluationsListView(),
          ),
          GoRoute(path: Routes.settings, builder: (context, state) => const SettingsView()),
        ],
      ),

      // Pantalla completa, apiladas sobre el shell. `/birds/new` va antes que
      // `/birds/:id` para que "new" no se interprete como un id.
      GoRoute(path: Routes.birdNew, builder: (context, state) => const BirdFormView()),
      // Antes que `/birds/:id`: si no, `clutch` se tomaría por un id.
      GoRoute(path: Routes.clutchNew, builder: (context, state) => const ClutchFormView()),
      GoRoute(
        path: Routes.evaluationNew,
        builder: (context, state) => EvaluationFormView(birdId: state.uri.queryParameters['bird']),
      ),
      GoRoute(
        path: '/birds/:id/pedigree',
        builder: (context, state) => PedigreeView(birdId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/birds/parent/:sex',
        builder: (context, state) => ParentPickerView(
          sex: Sex.fromId(state.pathParameters['sex']),
          excludeId: state.uri.queryParameters['exclude'],
        ),
      ),
      GoRoute(
        path: '/birds/:id',
        builder: (context, state) => BirdDetailView(birdId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => BirdFormView(birdId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  );
});

/// Puente entre los providers que condicionan la navegación y el
/// `refreshListenable` de go_router, que espera un `Listenable`.
class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
