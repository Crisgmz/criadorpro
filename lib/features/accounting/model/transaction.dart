import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';

/// Ingreso o gasto — `RF-CON-01`.
enum TransactionType {
  income('income'),
  expense('expense');

  const TransactionType(this.id);

  final String id;

  static TransactionType fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => TransactionType.expense);
}

/// Catálogo **cerrado** de categorías — `RF-CON-02`.
///
/// El usuario no crea categorías propias: añadir una exige migración. Las
/// claves se guardan en inglés y se traducen en presentación, que es lo que
/// permite revisar el vocabulario visible en los `.arb` sin tocar la base.
enum TransactionCategory {
  // Ingresos
  birdSale('bird_sale', TransactionType.income),
  breedingService('breeding_service', TransactionType.income),
  eggSale('egg_sale', TransactionType.income),
  otherIncome('other_income', TransactionType.income),

  // Gastos
  feed('feed', TransactionType.expense),
  medicine('medicine', TransactionType.expense),
  payroll('payroll', TransactionType.expense),
  transport('transport', TransactionType.expense),
  maintenance('maintenance', TransactionType.expense),
  birdPurchase('bird_purchase', TransactionType.expense),
  utilities('utilities', TransactionType.expense),
  otherExpense('other_expense', TransactionType.expense);

  const TransactionCategory(this.id, this.type);

  final String id;
  final TransactionType type;

  /// `payroll` es de uso exclusivo del sistema: la crea el módulo de
  /// empleomanía al confirmar un pago (`RS-06`) y **no aparece en el selector
  /// manual de gastos**. Si el criador pudiera elegirla, el gasto de nómina
  /// dejaría de cuadrar con los pagos registrados.
  bool get isSystemOnly => this == TransactionCategory.payroll;

  static TransactionCategory fromId(String? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => TransactionCategory.otherExpense);

  /// Las que el criador puede elegir a mano para un tipo dado.
  static List<TransactionCategory> selectableFor(TransactionType type) =>
      values.where((c) => c.type == type && !c.isSystemOnly).toList();
}

/// Periodicidad de un movimiento recurrente — `RF-CON-03`.
enum Recurrence {
  none('none'),
  weekly('weekly'),
  biweekly('biweekly'),
  monthly('monthly');

  const Recurrence(this.id);

  final String id;

  static Recurrence fromId(String? id) =>
      values.firstWhere((r) => r.id == id, orElse: () => Recurrence.none);

  /// Días que separan dos períodos. El mensual se resuelve por calendario y no
  /// por días, así que aquí no tiene valor.
  int? get days => switch (this) {
    Recurrence.weekly => 7,
    Recurrence.biweekly => 15,
    Recurrence.monthly => null,
    Recurrence.none => null,
  };
}

/// Movimiento contable.
class Transaction {
  const Transaction({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.category,
    required this.amountCents,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.birdId,
    this.recurrence = Recurrence.none,
    this.recurrenceSourceId,
    this.isDeleted = false,
  });

  factory Transaction.fromRow(TransactionRow row) => Transaction(
    id: row.id,
    ownerId: row.ownerId,
    type: TransactionType.fromId(row.type),
    category: TransactionCategory.fromId(row.category),
    amountCents: row.amountCents,
    date: row.date,
    description: row.description,
    birdId: row.birdId,
    recurrence: Recurrence.fromId(row.recurrence),
    recurrenceSourceId: row.recurrenceSourceId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory Transaction.fromRemoteJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    type: TransactionType.fromId(json['type'] as String?),
    category: TransactionCategory.fromId(json['category'] as String?),
    amountCents: centsOf(json['amount']),
    date: _parseDate(json['date']) ?? DateTime.now(),
    description: json['description'] as String?,
    birdId: json['bird_id'] as String?,
    recurrence: Recurrence.fromId(json['recurrence'] as String?),
    recurrenceSourceId: json['recurrence_source_id'] as String?,
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;
  final TransactionType type;
  final TransactionCategory category;

  /// Importe en centavos. En Postgres la columna es `numeric(12,2)`.
  final int amountCents;

  final DateTime date;
  final String? description;
  final String? birdId;
  final Recurrence recurrence;

  /// Movimiento del que este se generó (`RS-08`). `null` en los que escribió
  /// el criador a mano.
  final String? recurrenceSourceId;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Importe en unidades monetarias, para presentación y para el servidor.
  double get amount => amountCents / 100;

  /// `true` si es la plantilla de una serie recurrente y no una de sus copias.
  bool get isRecurringTemplate => recurrence != Recurrence.none && recurrenceSourceId == null;

  /// Convierte un importe a centavos redondeando al céntimo más cercano.
  ///
  /// El `round()` es imprescindible: `numeric(12,2)` llega como `double`, y
  /// `12.45 * 100` da `1244.9999...` en coma flotante. Truncar perdería un
  /// céntimo por movimiento.
  static int centsOf(Object? amount) {
    final value = (amount as num?)?.toDouble() ?? 0;
    return (value * 100).round();
  }

  TransactionsCompanion toCompanion({bool dirty = false}) => TransactionsCompanion(
    id: Value(id),
    ownerId: Value(ownerId),
    type: Value(type.id),
    category: Value(category.id),
    amountCents: Value(amountCents),
    date: Value(date),
    description: Value(description),
    birdId: Value(birdId),
    recurrence: Value(recurrence.id),
    recurrenceSourceId: Value(recurrenceSourceId),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    isDeleted: Value(isDeleted),
    isDirty: Value(dirty),
  );

  Map<String, dynamic> toRemoteJson() => {
    'id': id,
    'owner_id': ownerId,
    'type': type.id,
    'category': category.id,
    'amount': amount,
    'date': _formatDate(date),
    'description': description,
    'bird_id': birdId,
    'recurrence': recurrence.id,
    'recurrence_source_id': recurrenceSourceId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
  };

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Cierre de un mes — `RF-CON-04`.
class MonthlyBalance {
  const MonthlyBalance({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.byCategory,
  });

  MonthlyBalance.emptyFor(this.month) : incomeCents = 0, expenseCents = 0, byCategory = const {};

  final DateTime month;
  final int incomeCents;
  final int expenseCents;

  /// Desglose para `RF-CON-06`, en centavos y por categoría.
  final Map<TransactionCategory, int> byCategory;

  int get balanceCents => incomeCents - expenseCents;

  double get income => incomeCents / 100;
  double get expense => expenseCents / 100;
  double get balance => balanceCents / 100;

  /// `RF-CON-04` pide el balance negativo en rojo **y sin mensajes
  /// adicionales**: un mes en pérdidas es información, no un error que haya que
  /// explicarle al criador.
  bool get isNegative => balanceCents < 0;

  bool get isEmpty => incomeCents == 0 && expenseCents == 0;

  /// Peso de una categoría sobre el total de su tipo, de 0 a 1. Es lo que
  /// dibuja las barras proporcionales de la pantalla 31.
  double shareOf(TransactionCategory category) {
    final total = category.type == TransactionType.income ? incomeCents : expenseCents;
    if (total == 0) return 0;
    return (byCategory[category] ?? 0) / total;
  }
}
