import '../../../../l10n/generated/app_l10n.dart';
import '../../model/country.dart';

/// Nombre visible de cada país.
///
/// Vive en la capa de View porque es texto traducible: `RNF-27` no admite
/// cadenas visibles incrustadas en el modelo. El enum solo guarda el código
/// ISO y el prefijo.
String countryName(AppL10n l10n, Country country) => switch (country) {
  Country.dominicanRepublic => l10n.countryDO,
  Country.unitedStates => l10n.countryUS,
  Country.puertoRico => l10n.countryPR,
  Country.cuba => l10n.countryCU,
  Country.mexico => l10n.countryMX,
  Country.guatemala => l10n.countryGT,
  Country.elSalvador => l10n.countrySV,
  Country.honduras => l10n.countryHN,
  Country.nicaragua => l10n.countryNI,
  Country.costaRica => l10n.countryCR,
  Country.panama => l10n.countryPA,
  Country.colombia => l10n.countryCO,
  Country.venezuela => l10n.countryVE,
  Country.ecuador => l10n.countryEC,
  Country.peru => l10n.countryPE,
  Country.spain => l10n.countryES,
};
