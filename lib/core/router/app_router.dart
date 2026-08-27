import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting/view/accounting_view.dart';
import '../../features/accounting/view/transaction_form_view.dart';
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
import '../../features/birds/view/weight_form_view.dart';
import '../../features/dashboard/view/dashboard_shell.dart';
import '../../features/dashboard/view/dashboard_view.dart';
import '../../features/evaluations/view/evaluation_form_view.dart';
import '../../features/evaluations/view/evaluations_list_view.dart';
import '../../features/onboarding/view/farm_setup_view.dart';
import '../../features/onboarding/view/setup_done_view.dart';
import '../../features/payroll/view/employee_form_view.dart';
import '../../features/payroll/view/payment_form_view.dart';
import '../../features/payroll/view/payroll_view.dart';
import '../../features/pedigree/view/pedigree_view.dart';
import '../../features/settings/view/settings_view.dart';
import '../domain/sex.dart';
import '../providers/providers.dart';
import '../widgets/motion.dart';
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
      // Todas las rutas entran con la transición del prototipo (`slideIn`).
      // Las pestañas son la excepción: no se apilan, así que animan su
      // contenido dentro del shell en vez de deslizarse.
      // --- Entrada y autenticación (pantallas 1–10) ------------------------
      _page(Routes.splash, (context, state) => const SplashView()),
      _page(Routes.onboarding, (context, state) => const OnboardingView()),
      _page(Routes.welcome, (context, state) => const WelcomeView()),
      _page(Routes.login, (context, state) => const LoginView()),

      // `/signup/verify` se declara antes que `/signup` para que gane el path
      // completo y no se interprete «verify» como parte del alta.
      _page(
        Routes.verifyEmail,
        (context, state) => VerifyCodeView(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: VerificationPurpose.signUp,
        ),
      ),
      _page(Routes.signUp, (context, state) => const SignUpView()),

      _page(
        Routes.recoverCode,
        (context, state) => VerifyCodeView(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: VerificationPurpose.passwordRecovery,
        ),
      ),
      _page(Routes.recoverPassword, (context, state) => const NewPasswordView()),
      _page(Routes.recover, (context, state) => const ForgotPasswordView()),

      // --- Configuración inicial (pantallas 11–14) -------------------------
      _page(Routes.farmSetup, (context, state) => const FarmSetupView()),
      _page(Routes.onboardingDone, (context, state) => const SetupDoneView()),

      // --- Pestañas principales --------------------------------------------
      // Comparten shell, barra inferior y aviso sin conexión.
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(location: state.matchedLocation, child: child),
        routes: [
          // Sin transición de página: cambiar de pestaña no es apilar. El
          // movimiento lo pone el shell sobre el contenido.
          _tab(Routes.home, (context, state) => const DashboardView()),
          _tab(Routes.birds, (context, state) => const BirdsListView()),
          _tab(Routes.evaluations, (context, state) => const EvaluationsListView()),
          _tab(Routes.settings, (context, state) => const SettingsView()),
        ],
      ),

      // Pantalla completa, apiladas sobre el shell. `/birds/new` va antes que
      // `/birds/:id` para que "new" no se interprete como un id.
      _page(
        Routes.birdNew,
        (context, state) => BirdFormView(returnsResult: state.uri.queryParameters['return'] == '1'),
      ),
      // Antes que `/birds/:id`: si no, `clutch` se tomaría por un id.
      _page(Routes.clutchNew, (context, state) => const ClutchFormView()),
      _page(Routes.accounting, (context, state) => const AccountingView()),
      _page(Routes.transactionNew, (context, state) => const TransactionFormView()),

      // `/payroll/employee/new` antes que `/payroll/employee/:id`, para que
      // "new" no se interprete como un identificador.
      _page(Routes.payroll, (context, state) => const PayrollView()),
      _page(Routes.employeeNew, (context, state) => const EmployeeFormView()),
      _page(
        '/payroll/employee/:id',
        (context, state) => EmployeeFormView(employeeId: state.pathParameters['id']),
      ),
      _page(
        '/payroll/pay/:employeeId',
        (context, state) => PaymentFormView(employeeId: state.pathParameters['employeeId']!),
      ),
      _page(
        Routes.evaluationNew,
        (context, state) => EvaluationFormView(birdId: state.uri.queryParameters['bird']),
      ),
      _page(
        '/birds/:id/weight',
        (context, state) => WeightFormView(birdId: state.pathParameters['id']!),
      ),
      _page(
        '/birds/:id/pedigree',
        (context, state) => PedigreeView(birdId: state.pathParameters['id']!),
      ),
      _page(
        '/birds/parent/:sex',
        (context, state) => ParentPickerView(
          sex: Sex.fromId(state.pathParameters['sex']),
          excludeId: state.uri.queryParameters['exclude'],
        ),
      ),
      GoRoute(
        path: '/birds/:id',
        pageBuilder: (context, state) => CpPageTransition(
          key: state.pageKey,
          child: BirdDetailView(birdId: state.pathParameters['id']!),
        ),
        routes: [
          _page('edit', (context, state) => BirdFormView(birdId: state.pathParameters['id'])),
        ],
      ),
    ],
  );
});

/// Ruta apilada con la transición del prototipo.
GoRoute _page(String path, Widget Function(BuildContext, GoRouterState) build) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      CpPageTransition(key: state.pageKey, child: build(context, state)),
);

/// Pestaña del shell: sin transición propia.
GoRoute _tab(String path, Widget Function(BuildContext, GoRouterState) build) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: build(context, state)),
);

/// Puente entre los providers que condicionan la navegación y el
/// `refreshListenable` de go_router, que espera un `Listenable`.
class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
