import '../../../l10n/generated/app_l10n.dart';
import '../model/employee.dart';
import '../model/payroll_payment.dart';

/// Traducción de los catálogos de empleomanía.
///
/// Los valores se guardan como claves estables en inglés y se traducen aquí,
/// igual que las categorías contables: así el vocabulario visible se revisa en
/// los `.arb` sin tocar la base ni migrar nada.
String frequencyLabel(AppL10n l10n, PayFrequency frequency) => switch (frequency) {
  PayFrequency.weekly => l10n.frequencyWeekly,
  PayFrequency.biweekly => l10n.frequencyBiweekly,
  PayFrequency.monthly => l10n.frequencyMonthly,
};

String methodLabel(AppL10n l10n, PaymentMethod method) => switch (method) {
  PaymentMethod.cash => l10n.methodCash,
  PaymentMethod.transfer => l10n.methodTransfer,
  PaymentMethod.other => l10n.methodOther,
};
