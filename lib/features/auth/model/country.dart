import '../../../core/config/app_config.dart';

/// País del perfil y su prefijo telefónico.
///
/// Catálogo acotado al mercado inicial y a la expansión de fase 2 (Caribe y
/// Centroamérica hispanohablante) más los dos destinos de emigración con más
/// criadores dominicanos. El nombre visible no vive aquí: se resuelve en la
/// View con `countryName()` para respetar `RNF-27`.
enum Country {
  dominicanRepublic('DO', '1'),
  unitedStates('US', '1'),
  puertoRico('PR', '1'),
  cuba('CU', '53'),
  mexico('MX', '52'),
  guatemala('GT', '502'),
  elSalvador('SV', '503'),
  honduras('HN', '504'),
  nicaragua('NI', '505'),
  costaRica('CR', '506'),
  panama('PA', '507'),
  colombia('CO', '57'),
  venezuela('VE', '58'),
  ecuador('EC', '593'),
  peru('PE', '51'),
  spain('ES', '34');

  const Country(this.code, this.dialCode);

  /// ISO 3166-1 alfa-2 — se guarda en `profiles.country_code`.
  final String code;

  /// Prefijo internacional sin el `+`.
  final String dialCode;

  static Country get fallback => Country.fromCode(AppConfig.defaultCountryCode);

  static Country fromCode(String? code) =>
      values.firstWhere((country) => country.code == code, orElse: () => Country.dominicanRepublic);

  /// `true` para los países del plan de numeración norteamericano, que agrupan
  /// el número como `(809) 555-1234`.
  bool get usesNorthAmericanFormat => dialCode == '1';

  /// Compone el E.164 que se persiste — SRS §4: `+18095551234`.
  String toE164(String localNumber) {
    final digits = localNumber.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '' : '+$dialCode$digits';
  }

  /// Formato de presentación del número local, sin el prefijo.
  String formatLocal(String localNumber) {
    final digits = localNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (usesNorthAmericanFormat && digits.length >= 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, 10)}';
    }
    // Resto de países: grupos de tres desde la izquierda, que es como se leen
    // en voz alta en la región.
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += 3) {
      groups.add(digits.substring(i, (i + 3).clamp(0, digits.length)));
    }
    return groups.join(' ');
  }
}
