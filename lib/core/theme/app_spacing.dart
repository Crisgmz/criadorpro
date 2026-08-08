/// Escala de espaciado y radios. Nada de números mágicos en las Views.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;

  /// Margen lateral de las pantallas de contenido — PRD §6 (20–24 px).
  static const double screen = 20;

  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  /// Insignias de sexo y de estado — PRD §6.
  static const double badge = 6;

  static const double sm = 8;

  /// Botones y campos de texto — PRD §6.
  static const double md = 12;

  /// Tarjetas — PRD §6.
  static const double card = 16;

  static const double lg = 20;
  static const double pill = 999;
}

/// Medidas de los controles fijadas por el sistema de diseño.
abstract final class AppSizes {
  /// Alto de botones y campos de texto — PRD §6.
  static const double control = 52;

  /// Área táctil mínima — `RNF-23`.
  static const double minTouchTarget = 44;
}
