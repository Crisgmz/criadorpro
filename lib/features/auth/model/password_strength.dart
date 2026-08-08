import '../../../core/config/app_config.dart';

/// Calificación del medidor de fuerza de la pantalla 4.
///
/// `RV-02` es explícito: el medidor **no bloquea por sí solo**. Lo único que
/// impide enviar el formulario es `Validators.password` (mínimo 8 caracteres
/// con letra y número). Esto solo informa.
enum PasswordStrength {
  /// Cadena vacía: el medidor no se pinta.
  none,
  weak,
  medium,
  strong;

  static PasswordStrength of(String password) {
    if (password.isEmpty) return PasswordStrength.none;

    var score = 0;
    if (password.length >= AppConfig.minPasswordLength) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-záéíóúüñ]').hasMatch(password) && RegExp(r'[A-ZÁÉÍÓÚÜÑ]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^\w\s]').hasMatch(password)) score++;

    // Por debajo del mínimo legal nunca sube de "débil", aunque sea variada:
    // sería engañoso premiar una contraseña que el formulario va a rechazar.
    if (password.length < AppConfig.minPasswordLength) return PasswordStrength.weak;

    return switch (score) {
      <= 2 => PasswordStrength.weak,
      3 || 4 => PasswordStrength.medium,
      _ => PasswordStrength.strong,
    };
  }

  /// Proporción de la barra, de 0 a 1.
  double get fraction => switch (this) {
    PasswordStrength.none => 0,
    PasswordStrength.weak => 1 / 3,
    PasswordStrength.medium => 2 / 3,
    PasswordStrength.strong => 1,
  };
}
