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

  /// Pruebas de campo — `RF-PRU`. Pestaña propia en la barra inferior: es una
  /// de las cosas que el criador consulta a diario.
  static const String evaluations = '/tests';

  /// Contabilidad — `RF-CON`. **No ocupa pestaña** (PRD §7): es un módulo
  /// administrativo que se abre a pantalla completa desde Inicio y Mi cuenta.
  /// La barra inferior se reserva a lo que el criador toca a diario.
  /// Comunidad — `RF-COM`. Pestaña propia: es de lo poco que el criador abre
  /// sin venir a registrar nada.
  static const String community = '/community';

  /// Pantalla 13 — Mi perfil. Cuelga de Mi cuenta, no del shell: se abre y se
  /// vuelve, no es un destino donde uno se queda.
  static const String profile = '/account/profile';

  /// Pantalla 15 — Soporte.
  static const String support = '/account/support';

  /// Solicitud de encuentro a un criadero concreto. El destinatario va en la
  /// ruta porque la pantalla no existe sin él.
  static String meetingRequestFor(String ownerId) => '/community/request/$ownerId';

  static const String accounting = '/accounting';

  static const String transactionNew = '/accounting/new';

  /// Empleomanía — `RF-NOM`. Tampoco ocupa pestaña, por lo mismo que
  /// contabilidad: es administración, no lo que el criador toca a diario.
  static const String payroll = '/payroll';

  static const String employeeNew = '/payroll/employee/new';

  static String employeeEdit(String id) => '/payroll/employee/$id';

  /// Registro de pago. El empleado va en la ruta porque la pantalla no tiene
  /// sentido sin él: se llega desde su fila, nunca en vacío.
  static String paymentNewFor(String employeeId) => '/payroll/pay/$employeeId';

  // Pantallas a pantalla completa, fuera del shell.
  static const String birdNew = '/birds/new';

  /// Alta que **devuelve** el ejemplar creado en lugar de navegar.
  ///
  /// La usa el selector de progenitor (pantalla 18): allí el alta es un paso
  /// dentro de otra tarea, y llevarse al criador a la lista de ejemplares le
  /// haría perder el formulario que estaba rellenando.
  static const String birdNewForResult = '$birdNew?return=1';

  /// Registro de camada (`RF-REG-08`). Cuelga de ejemplares porque lo que crea
  /// son ejemplares, pero se abre a pantalla completa: es un formulario de
  /// captura rápida y la barra inferior solo distraería.
  static const String clutchNew = '/birds/clutch/new';

  /// Pantalla 25. Con `birdId` la prueba se abre desde la ficha, con el
  /// ejemplar ya elegido.
  static const String evaluationNew = '/tests/new';

  static String evaluationNewFor(String birdId) => '$evaluationNew?bird=$birdId';

  /// Pantalla 18 (`RF-REG-11`). Devuelve la elección por `pop`, no navega:
  /// el formulario que la abrió sigue vivo detrás con lo ya capturado.
  static String parentPicker(String sexId, {String? excludeId}) =>
      '/birds/parent/$sexId${excludeId == null ? '' : '?exclude=$excludeId'}';

  static String birdDetail(String id) => '/birds/$id';

  /// Anotar una pesada — `RF-REG-14`.
  static String birdWeightNew(String id) => '/birds/$id/weight';
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
