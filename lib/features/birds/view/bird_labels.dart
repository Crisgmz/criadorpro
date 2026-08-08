import '../../../core/domain/sex.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/bird.dart';

/// Etiquetas traducidas de los enums del feature.
///
/// Están en la capa de View: los enums son datos, y su nombre visible depende
/// del idioma.

String sexLabel(AppL10n l10n, Sex sex) => switch (sex) {
  Sex.male => l10n.sexMale,
  Sex.female => l10n.sexFemale,
  Sex.unknown => l10n.sexUnknown,
};

String statusLabel(AppL10n l10n, BirdStatus status) => switch (status) {
  BirdStatus.active => l10n.statusActive,
  BirdStatus.sold => l10n.statusSold,
  BirdStatus.deceased => l10n.statusDeceased,
  BirdStatus.loaned => l10n.statusLoaned,
};

/// Edad legible: días las primeras semanas, luego meses, luego años y meses.
String ageLabel(AppL10n l10n, DateTime? birthDate) {
  if (birthDate == null) return l10n.ageUnknown;
  final age = Formatters.age(birthDate);
  if (age.isNewborn) return l10n.ageDays(age.totalDays);
  if (age.isUnderOneYear) return l10n.ageMonths(age.months);
  return l10n.ageYearsMonths(age.years, age.months);
}
