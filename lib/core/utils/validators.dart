import '../config/app_config.dart';

/// Validaciones puras, sin dependencia de Flutter ni de traducciones.
///
/// Devuelven un [ValidationError] o `null`. La View lo convierte a texto con
/// `validationMessage()` para poder mostrarlo en el idioma del usuario.
enum ValidationError {
  required,
  email,
  emailTooLong,
  passwordTooShort,
  passwordNeedsLetterAndNumber,
  passwordMismatch,
  nameLength,
  farmNameLength,
  plateOutOfRange,
  codeIncomplete,
  phoneInvalid,
  notANumber,
}

abstract final class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _hasLetter = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
  static final RegExp _hasDigit = RegExp(r'\d');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  static ValidationError? required(String? value) =>
      (value == null || value.trim().isEmpty) ? ValidationError.required : null;

  /// `RV-01` — formato válido y hasta 254 caracteres.
  static ValidationError? email(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final normalized = normalizeEmail(value!);
    if (normalized.length > 254) return ValidationError.emailTooLong;
    return _email.hasMatch(normalized) ? null : ValidationError.email;
  }

  /// El correo se normaliza a minúsculas antes de enviarlo — `RV-01`.
  static String normalizeEmail(String value) => value.trim().toLowerCase();

  /// `RV-02` — mínimo 8 caracteres con al menos una letra y un número.
  ///
  /// El medidor de fuerza es informativo y no bloquea por sí solo: solo esta
  /// regla decide si el formulario puede enviarse.
  static ValidationError? password(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    if (value!.length < AppConfig.minPasswordLength) return ValidationError.passwordTooShort;
    if (!_hasLetter.hasMatch(value) || !_hasDigit.hasMatch(value)) {
      return ValidationError.passwordNeedsLetterAndNumber;
    }
    return null;
  }

  /// `RV-03` — coincidencia exacta con la contraseña.
  static ValidationError? passwordConfirmation(String? value, String password) {
    final missing = required(value);
    if (missing != null) return missing;
    return value == password ? null : ValidationError.passwordMismatch;
  }

  /// `RV-04` — exactamente 6 dígitos numéricos.
  static ValidationError? verificationCode(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final trimmed = value!.trim();
    return trimmed.length == AppConfig.verificationCodeLength && _digitsOnly.hasMatch(trimmed)
        ? null
        : ValidationError.codeIncomplete;
  }

  /// `RV-06` — nombre del criadero: obligatorio, 2–60 caracteres. Los espacios
  /// de los extremos se recortan antes de medir y de guardar.
  static ValidationError? farmName(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final length = value!.trim().length;
    return (length < 2 || length > 60) ? ValidationError.farmNameLength : null;
  }

  /// `RV-07` — placa con la que el criador va hoy: entero de 1 a 999.999.
  ///
  /// La regla completa añade «no puede ser menor que la placa más alta ya
  /// registrada», que no se puede comprobar aquí porque exige consultar los
  /// ejemplares. En el onboarding todavía no hay ninguno; cuando el ajuste de
  /// numeración exista fuera del alta, esa parte irá en el repositorio.
  static ValidationError? initialPlate(String? value) {
    final missing = required(value);
    if (missing != null) return missing;

    final plate = int.tryParse(value!.trim());
    if (plate == null) return ValidationError.notANumber;
    return (plate < 1 || plate > maxInitialPlate) ? ValidationError.plateOutOfRange : null;
  }

  static const int maxInitialPlate = 999999;

  /// `RV-08` — placa del ejemplar: obligatoria y entera, de 1 en adelante.
  ///
  /// Que esté duplicada no se comprueba aquí: exige consultar la base y, sobre
  /// todo, no es motivo de rechazo sino de advertencia.
  static ValidationError? plate(String? value) {
    final missing = required(value);
    if (missing != null) return missing;

    final plate = int.tryParse(value!.trim());
    if (plate == null) return ValidationError.notANumber;
    return (plate < 1 || plate > maxInitialPlate) ? ValidationError.plateOutOfRange : null;
  }

  /// `RV-12` — peso razonable para un ejemplar, en gramos. Fuera de rango se
  /// advierte pero se permite guardar, así que esto devuelve un booleano y no
  /// un error de validación.
  static bool isWeightInRange(int grams) => grams >= minWeightG && grams <= maxWeightG;

  static const int minWeightG = 100;
  static const int maxWeightG = 8000;

  /// Nombre completo del usuario: 2–80 caracteres (SRS · `profiles.full_name`).
  static ValidationError? fullName(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final length = value!.trim().length;
    return (length < 2 || length > 80) ? ValidationError.nameLength : null;
  }

  /// Teléfono opcional: `profiles.phone` admite nulo, así que vacío es válido.
  /// Si se escribe, necesita entre 7 y 15 dígitos para componer un E.164 con el
  /// prefijo del país.
  static ValidationError? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = digitsOf(value);
    return (digits.length < 7 || digits.length > 15) ? ValidationError.phoneInvalid : null;
  }

  /// Número opcional: vacío es válido, texto no numérico no lo es.
  static ValidationError? optionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.')) == null
        ? ValidationError.notANumber
        : null;
  }

  static String digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');
}
