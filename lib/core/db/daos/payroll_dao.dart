import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/employees.dart';
import '../tables/payroll_payments.dart';

part 'payroll_dao.g.dart';

/// Empleados y pagos en un mismo acceso: nunca se consultan por separado —una
/// nómina sin su empleado no dice nada— y así las dos tablas comparten
/// transacción cuando hace falta.
@DriftAccessor(tables: [Employees, PayrollPayments])
class PayrollDao extends DatabaseAccessor<AppDatabase> with _$PayrollDaoMixin {
  PayrollDao(super.db);

  // --- Empleados -----------------------------------------------------------

  /// Plantilla del criadero — `RF-NOM-02`.
  ///
  /// Los activos primero y por nombre: quien se va deja de estorbar arriba
  /// pero sigue consultable, que es lo que exige `RS-03`.
  Stream<List<EmployeeRow>> watchEmployees({required String ownerId, bool activeOnly = false}) {
    final query = select(employees)
      ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false));

    if (activeOnly) query.where((t) => t.isActive.equals(true));

    query.orderBy([
      (t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
    return query.watch();
  }

  /// Los activos, para el costo mensual estimado de `RS-07`.
  Future<List<EmployeeRow>> activeEmployees(String ownerId) =>
      (select(employees)..where(
            (t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false) & t.isActive.equals(true),
          ))
          .get();

  Future<EmployeeRow?> findEmployee(String id) =>
      (select(employees)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Fotos que están en el teléfono y no en Storage — pantalla 30.
  Future<List<EmployeeRow>> photosPendingUpload(String ownerId) =>
      (select(employees)..where(
            (t) =>
                t.ownerId.equals(ownerId) &
                t.isDeleted.equals(false) &
                t.photoPath.isNotNull() &
                t.photoUrl.isNull(),
          ))
          .get();

  Future<List<EmployeeRow>> photosPendingDownload(String ownerId) =>
      (select(employees)..where(
            (t) =>
                t.ownerId.equals(ownerId) &
                t.isDeleted.equals(false) &
                t.photoUrl.isNotNull() &
                t.photoPath.isNull(),
          ))
          .get();

  /// Ruta local de la foto. **No se sincroniza**: una ruta de este teléfono no
  /// significa nada en otro, por eso se escribe sin marcar la fila como sucia.
  Future<void> setEmployeePhotoPath(String id, String? path) => (update(
    employees,
  )..where((t) => t.id.equals(id))).write(EmployeesCompanion(photoPath: Value(path)));

  Future<void> upsertEmployee(EmployeesCompanion employee) =>
      into(employees).insertOnConflictUpdate(employee);

  Future<void> upsertEmployees(List<EmployeesCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(employees, rows);
  });

  Future<void> softDeleteEmployee(String id, DateTime deletedAt) =>
      (update(employees)..where((t) => t.id.equals(id))).write(
        EmployeesCompanion(
          isDeleted: const Value(true),
          isDirty: const Value(true),
          updatedAt: Value(deletedAt),
        ),
      );

  // --- Pagos ---------------------------------------------------------------

  /// Historial de pagos del criadero, lo más reciente primero.
  Stream<List<PayrollPaymentRow>> watchPayments({required String ownerId, String? employeeId}) {
    final query = select(payrollPayments)
      ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false));

    if (employeeId != null) query.where((t) => t.employeeId.equals(employeeId));

    query.orderBy([(t) => OrderingTerm(expression: t.periodStart, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<PayrollPaymentRow?> findPayment(String id) =>
      (select(payrollPayments)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Pagos vivos de un empleado que se solapan con un período.
  ///
  /// Es lo que impide pagarle dos veces la misma quincena: el criador que abre
  /// la pantalla, se distrae y vuelve a entrar no debería poder duplicar el
  /// gasto sin enterarse.
  Future<List<PayrollPaymentRow>> overlapping({
    required String employeeId,
    required DateTime start,
    required DateTime end,
    String? excludeId,
  }) {
    final query = select(payrollPayments)
      ..where(
        (t) =>
            t.employeeId.equals(employeeId) &
            t.isDeleted.equals(false) &
            // Dos intervalos se solapan si cada uno empieza antes de que
            // termine el otro. Comparar solo los inicios dejaría pasar un pago
            // contenido dentro de otro.
            t.periodStart.isSmallerOrEqualValue(end) &
            t.periodEnd.isBiggerOrEqualValue(start),
      );

    if (excludeId != null) query.where((t) => t.id.equals(excludeId).not());
    return query.get();
  }

  Future<void> upsertPayment(PayrollPaymentsCompanion payment) =>
      into(payrollPayments).insertOnConflictUpdate(payment);

  Future<void> upsertPayments(List<PayrollPaymentsCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(payrollPayments, rows);
  });

  Future<void> softDeletePayment(String id, DateTime deletedAt) =>
      (update(payrollPayments)..where((t) => t.id.equals(id))).write(
        PayrollPaymentsCompanion(
          isDeleted: const Value(true),
          isDirty: const Value(true),
          updatedAt: Value(deletedAt),
        ),
      );

  Future<void> clear() async {
    await delete(payrollPayments).go();
    await delete(employees).go();
  }
}
