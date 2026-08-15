/// Rutas de la app en un solo sitio: nadie escribe paths a mano en las Views.
abstract final class Routes {
  // --- Públicas: accesibles sin sesión (RF-AUT) ---------------------------

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signUp = '/signup';
  static const String verifyEmail = '/signup/verify';
  static const String login = '/login';

  /// Recuperación en tres pasos: correo → código → nueva contraseña.
  static const String recover = '/recover';
  static const String recoverCode = '/recover/code';
  static const String recoverPassword = '/recover/password';

  // --- Configuración inicial (RF-ONB) --------------------------------------
  //
  // Exige sesión, pero no son privadas del todo: mientras el criadero no tenga
  // nombre, la guardia manda aquí y no deja entrar a ninguna otra pantalla.

  static const String farmSetup = '/onboarding/profile';
  static const String onboardingDone = '/onboarding/done';

  // --- Privadas ------------------------------------------------------------

  // Pestañas del shell.
  static const String home = '/home';
  static const String birds = '/birds';
  static const String settings = '/settings';

  // Pantallas a pantalla completa, fuera del shell.
  static const String birdNew = '/birds/new';

  /// Registro de camada (`RF-REG-08`). Cuelga de ejemplares porque lo que crea
  /// son ejemplares, pero se abre a pantalla completa: es un formulario de
  /// captura rápida y la barra inferior solo distraería.
  static const String clutchNew = '/birds/clutch/new';

  /// Pantalla 18 (`RF-REG-11`). Devuelve la elección por `pop`, no navega:
  /// el formulario que la abrió sigue vivo detrás con lo ya capturado.
  static String parentPicker(String sexId, {String? excludeId}) =>
      '/birds/parent/$sexId${excludeId == null ? '' : '?exclude=$excludeId'}';

  static String birdDetail(String id) => '/birds/$id';
  static String birdEdit(String id) => '/birds/$id/edit';

  /// Pantalla 23 — `RF-PED`.
  static String birdPedigree(String id) => '/birds/$id/pedigree';

  // --- Ayudas --------------------------------------------------------------

  /// El correo viaja en la query porque las pantallas de código lo necesitan
  /// para verificar y reenviar, y así el flujo sobrevive a una recomposición
  /// sin depender de un ViewModel compartido entre pantallas.
  static String verifyEmailFor(String email) => '$verifyEmail?email=${Uri.encodeComponent(email)}';

  static String recoverCodeFor(String email) => '$recoverCode?email=${Uri.encodeComponent(email)}';

  static const Set<String> _public = {
    splash,
    onboarding,
    welcome,
    signUp,
    verifyEmail,
    login,
    recover,
    recoverCode,
    recoverPassword,
  };

  static bool isPublic(String path) => _public.contains(path);

  /// Pantallas de la configuración inicial. Con sesión abierta y criadero sin
  /// nombre son las únicas alcanzables (`RF-ONB`).
  static bool isFarmSetup(String path) => path.startsWith('/onboarding/');

  /// El flujo de recuperación queda fuera de las guardias: verificar el código
  /// abre sesión, y sin esta excepción el redirect sacaría al usuario a Inicio
  /// justo antes de que pueda escribir su contraseña nueva.
  static bool isRecoveryFlow(String path) => path.startsWith(recover);
}
