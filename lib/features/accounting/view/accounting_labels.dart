import '../../../l10n/generated/app_l10n.dart';
import '../model/transaction.dart';

/// Traducción de los catálogos cerrados — `RF-CON-02`.
///
/// Las claves viven en inglés en la base y se traducen aquí. Es lo que permite
/// revisar el vocabulario visible en los `.arb` sin tocar datos ni servidor.
String categoryLabel(AppL10n l10n, TransactionCategory category) => switch (category) {
  TransactionCategory.birdSale => l10n.categoryBirdSale,
  TransactionCategory.breedingService => l10n.categoryBreedingService,
  TransactionCategory.eggSale => l10n.categoryEggSale,
  TransactionCategory.otherIncome => l10n.categoryOtherIncome,
  TransactionCategory.feed => l10n.categoryFeed,
  TransactionCategory.medicine => l10n.categoryMedicine,
  TransactionCategory.payroll => l10n.categoryPayroll,
  TransactionCategory.transport => l10n.categoryTransport,
  TransactionCategory.maintenance => l10n.categoryMaintenance,
  TransactionCategory.birdPurchase => l10n.categoryBirdPurchase,
  TransactionCategory.utilities => l10n.categoryUtilities,
  TransactionCategory.otherExpense => l10n.categoryOtherExpense,
};

String typeLabel(AppL10n l10n, TransactionType type) => switch (type) {
  TransactionType.income => l10n.typeIncome,
  TransactionType.expense => l10n.typeExpense,
};

String recurrenceLabel(AppL10n l10n, Recurrence recurrence) => switch (recurrence) {
  Recurrence.none => l10n.recurrenceNone,
  Recurrence.weekly => l10n.recurrenceWeekly,
  Recurrence.biweekly => l10n.recurrenceBiweekly,
  Recurrence.monthly => l10n.recurrenceMonthly,
};
