import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colores con significado de dominio: sexo, resultado de prueba y aviso.
///
/// No caben en el `ColorScheme` de Material —no son `primary` ni `error`, son
/// vocabulario del oficio— pero sí cambian con el tema: los tonos del PRD están
/// calculados sobre blanco y sobre el navy profundo no llegan al 4,5:1 de
/// `RNF-22`. Viajan como extensión del tema para que ningún widget tenga que
/// preguntar por el brillo.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.male,
    required this.female,
    required this.unknownSex,
    required this.warning,
    required this.action,
    required this.brand,
  });

  /// Convención cerrada: verde macho, azul hembra, gris sin definir.
  final Color male;
  final Color female;
  final Color unknownSex;

  /// Ámbar de aviso: sin conexión, cerca del límite de plan.
  final Color warning;

  /// Rojo de resultado desfavorable. Es el mismo rojo de acción del PRD.
  final Color action;

  /// Navy de marca **como acento sobre contenido**. En oscuro no puede ser el
  /// navy literal: sería el color del fondo.
  final Color brand;

  static const SemanticColors light = SemanticColors(
    male: AppColors.male,
    female: AppColors.female,
    unknownSex: AppColors.unknownSex,
    warning: AppColors.warning,
    action: AppColors.action,
    brand: AppColors.navy,
  );

  static const SemanticColors dark = SemanticColors(
    male: AppColors.maleLight,
    female: AppColors.femaleLight,
    unknownSex: AppColors.unknownSexLight,
    warning: AppColors.warningLight,
    action: AppColors.actionLight,
    brand: Color(0xFFA9C3DE),
  );

  /// Resultado de prueba de campo (`RF-PRU`): reutiliza el verde y el rojo del
  /// sistema para no abrir una segunda escala cromática. El color nunca va
  /// solo — siempre lo acompaña la etiqueta (`RNF-25`).
  Color get favorable => male;
  Color get unfavorable => action;
  Color get undefinedResult => unknownSex;

  @override
  SemanticColors copyWith({
    Color? male,
    Color? female,
    Color? unknownSex,
    Color? warning,
    Color? action,
    Color? brand,
  }) => SemanticColors(
    male: male ?? this.male,
    female: female ?? this.female,
    unknownSex: unknownSex ?? this.unknownSex,
    warning: warning ?? this.warning,
    action: action ?? this.action,
    brand: brand ?? this.brand,
  );

  @override
  SemanticColors lerp(SemanticColors? other, double t) {
    if (other == null) return this;
    return SemanticColors(
      male: Color.lerp(male, other.male, t)!,
      female: Color.lerp(female, other.female, t)!,
      unknownSex: Color.lerp(unknownSex, other.unknownSex, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      action: Color.lerp(action, other.action, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
    );
  }
}

extension SemanticColorsX on BuildContext {
  /// Paleta de dominio del tema vigente.
  ///
  /// Cae a la variante clara si nadie registró la extensión —solo pasa en
  /// pruebas que montan un `ThemeData` pelado— para no reventar el árbol.
  SemanticColors get semantic => Theme.of(this).extension<SemanticColors>() ?? SemanticColors.light;
}
