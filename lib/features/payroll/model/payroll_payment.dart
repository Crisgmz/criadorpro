import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';
import 'employee.dart';

/// Forma de pago — SRS `payroll_payments.method`, catálogo cerrado.
enum PaymentMethod {
  cash('cash'),
  transfer('transfer'),
  other('other');

  const PaymentMethod(this.id);

  final String id;

  static PaymentMethod fromId(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => PaymentMethod.cash);
}

/// Pago de nómina — `RF-NOM-03`.
class PayrollPayment {
  const PayrollPayment({
    required this.id,
    required this.ownerId,
    required this.employeeId,
    required this.periodStart,
    required this.periodEnd,
    required this.baseCents,
    required this.method,
    required this.createdAt,
    required this.updatedAt,
    this.bonusCents = 0,
    this.deductionsCents = 0,
    this.transactionId,
    this.isDeleted = false,
  });

  factory PayrollPayment.fromRow(PayrollPaymentRow row) => PayrollPayment(
    id: row.id,
    ownerId: row.ownerId,
    employeeId: row.employeeId,
    periodStart: row.periodStart,
    periodEnd: row.periodEnd,
    baseCents: row.baseCents,
    bonusCents: row.bonusCents,
    deductionsCents: row.deductionsCents,
    method: PaymentMethod.fromId(row.method),
    transactionId: row.transactionId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory PayrollPayment.fromRemoteJson(Map<String, dynamic> json) => PayrollPayment(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    employeeId: json['employee_id'] as String,
    periodStart: Money.parseDate(json['period_start']) ?? DateTime.now(),
    periodEnd: Money.parseDate(json['period_end']) ?? DateTime.now(),
    baseCents: Money.centsOf(json['base']),
    bonusCents: Money.centsOf(json['bonus']),
    deductionsCents: Money.centsOf(json['deductions']),
    method: PaymentMethod.fromId(json['method'] as String?),
    transactionId: json['transaction_id'] as String?,
    createdAt: Money.parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: Money.parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;
  final String employeeId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int baseCents;
  final int bonusCents;
  final int deductionsCents;
  final PaymentMethod method;

  /// Gasto de nómina que este pago generó (`RS-06`).
  final String? transactionId;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Neto **calculado**, nunca editable (SRS `payroll_payments.net`).
  ///
  /// Se deriva en vez de leerse de la columna: si alguna vez el guardado y el
  /// cálculo divergieran, lo que ve el criador debe ser la cuenta, no el
  /// número que quedó grabado.
  int get netCents => baseCents + bonusCents - deductionsCents;

  double get base => baseCents / 100;
  double get bonus => bonusCents / 100;
  double get deductions => deductionsCents / 100;
  double get net => netCents / 100;

  PayrollPaymentsCompanion toCompanion({bool dirty = false}) => PayrollPaymentsCompanion(
    id: Value(id),
    ownerId: Value(ownerId),
    employeeId: Value(employeeId),
    periodStart: Value(periodStart),
    periodEnd: Value(periodEnd),
    baseCents: Value(baseCents),
    bonusCents: Value(bonusCents),
    deductionsCents: Value(deductionsCents),
    netCents: Value(netCents),
    method: Value(method.id),
    transactionId: Value(transactionId),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    isDeleted: Value(isDeleted),
    isDirty: Value(dirty),
  );

  Map<String, dynamic> toRemoteJson() => {
    'id': id,
    'owner_id': ownerId,
    'employee_id': employeeId,
    'period_start': Money.formatDate(periodStart),
    'period_end': Money.formatDate(periodEnd),
    'base': base,
    'bonus': bonus,
    'deductions': deductions,
    'net': net,
    'method': method.id,
    'transaction_id': transactionId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
  };
}

/// Costo mensual estimado de la plantilla — `RS-07`.
class PayrollSummary {
  const PayrollSummary({
    required this.activeCount,
    required this.monthlyCostCents,
    required this.paidThisMonthCents,
  });

  const PayrollSummary.empty() : activeCount = 0, monthlyCostCents = 0, paidThisMonthCents = 0;

  final int activeCount;

  /// Suma de salarios activos normalizados a un mes. **Es una estimación** y la
  /// pantalla tiene que decirlo: nadie cobra 4,33 semanas en un mes concreto.
  final int monthlyCostCents;

  /// Lo realmente pagado en el mes en curso, que sí es un dato exacto y sirve
  /// para contrastar la estimación.
  final int paidThisMonthCents;

  double get monthlyCost => monthlyCostCents / 100;
  double get paidThisMonth => paidThisMonthCents / 100;
}
