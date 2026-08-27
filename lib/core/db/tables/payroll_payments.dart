import 'package:drift/drift.dart';

/// Pago de nómina — `RF-NOM-03`.
@DataClassName('PayrollPaymentRow')
class PayrollPayments extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get employeeId => text()();

  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();

  /// Todo en centavos. El neto **se calcula** —base + bono − deducciones— y no
  /// es editable (SRS `payroll_payments.net`); se guarda igual porque el recibo
  /// tiene que poder reimprimirse tal cual se emitió, aunque el salario del
  /// empleado cambie después.
  IntColumn get baseCents => integer()();
  IntColumn get bonusCents => integer().withDefault(const Constant(0))();
  IntColumn get deductionsCents => integer().withDefault(const Constant(0))();
  IntColumn get netCents => integer()();

  /// `cash` · `transfer` · `other`.
  TextColumn get method => text()();

  /// Gasto de categoría nómina que este pago generó (`RS-06`).
  ///
  /// Se guarda la referencia para poder **anular los dos juntos**: sin ella,
  /// anular un pago dejaría el gasto huérfano y el mes cerraría con un importe
  /// que no corresponde a ningún pago.
  TextColumn get transactionId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
