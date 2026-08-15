/// Planes de suscripción. El límite se aplica en el repositorio, no en la UI.
enum SubscriptionPlan {
  free(id: 'free', birdLimit: 25, pedigreeDepth: 2, productId: null),
  pro(id: 'pro', birdLimit: 500, pedigreeDepth: 4, productId: 'com.criadorpro.pro.monthly'),
  elite(id: 'elite', birdLimit: null, pedigreeDepth: 4, productId: 'com.criadorpro.elite.monthly');

  const SubscriptionPlan({
    required this.id,
    required this.birdLimit,
    required this.pedigreeDepth,
    required this.productId,
  });

  /// Valor persistido en `profiles.plan`.
  final String id;

  /// Máximo de ejemplares. `null` = ilimitado.
  final int? birdLimit;

  /// Generaciones ascendentes visibles en el pedigrí — `RF-PED-03`.
  /// El plan gratuito llega a dos; Pro y Élite, a cuatro.
  final int pedigreeDepth;

  /// Identificador de producto en App Store / Play Console.
  final String? productId;

  bool get isUnlimited => birdLimit == null;

  static SubscriptionPlan fromId(String? id) =>
      values.firstWhere((plan) => plan.id == id, orElse: () => SubscriptionPlan.free);
}

abstract final class AppConfig {
  static const String databaseName = 'criadorpro';

  /// Generaciones que muestra el árbol genealógico.
  static const int maxPedigreeGenerations = 4;

  /// Proporción del límite de plan a partir de la cual Inicio avisa
  /// (`RF-REG-02`). El margen del 20 % da tiempo a reaccionar antes de que la
  /// app deje de admitir altas.
  static const double planWarningThreshold = 0.8;

  /// Intervalo del reintento periódico de la cola de sincronización.
  static const Duration syncInterval = Duration(minutes: 5);

  /// Tras este número de intentos fallidos, una entrada de la cola deja de
  /// reintentarse automáticamente y requiere sincronización manual.
  static const int maxSyncAttempts = 5;

  static const int minPasswordLength = 8;

  /// Tiempo que se muestra la pantalla de entrada antes de derivar — `RF-AUT-01`.
  static const Duration splashDuration = Duration(seconds: 2);

  // --- Verificación por código (RF-AUT-06 · RV-04) ------------------------

  /// Dígitos del código de verificación que llega al correo.
  static const int verificationCodeLength = 6;

  /// Vigencia del código. Es informativa en el cliente: quien la impone de
  /// verdad es Supabase, y hay que configurarla igual en el panel.
  static const Duration verificationCodeTtl = Duration(minutes: 10);

  /// Espera antes de habilitar el reenvío del código — `RF-AUT-08`.
  static const Duration resendCodeCooldown = Duration(seconds: 60);

  /// Intentos por código antes de que Supabase lo invalide — `RV-04`.
  static const int maxVerificationAttempts = 5;

  // --- Enlaces legales (RF-CTA-12) ---------------------------------------

  static const String termsUrl = 'https://criadorpro.app/terminos';
  static const String privacyUrl = 'https://criadorpro.app/privacidad';

  /// País por omisión del perfil — SRS · `profiles.country_code`.
  static const String defaultCountryCode = 'DO';

  /// Idiomas que admite `profiles.locale`. El español es el origen del
  /// producto; el inglés es traducción.
  static const List<String> supportedLocales = ['es', 'en'];

  static const String defaultLocale = 'es';
}
