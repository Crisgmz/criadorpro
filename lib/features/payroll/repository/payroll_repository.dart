import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/accounting/payroll_expense_sink.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/payroll_dao.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../model/employee.dart';
import '../model/payroll_payment.dart';

/// Empleomanía — `RF-NOM`.
///
/// Dos tablas remotas y un puente con contabilidad. Implementa dos
/// [RemotePuller] porque `employees` y `payroll_payments` bajan por separado,
/// pero la clase es una sola: los pagos no significan nada sin sus empleados y
/// separarlas obligaría a duplicar el acceso.
class PayrollRepository {
  PayrollRepository({
    required AppDatabase database,
    required PayrollDao payrollDao,
    required ProfilesDao profilesDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    required PayrollExpenseSink expenses,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _payrollDao = payrollDao,
       _profilesDao = profilesDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _expenses = expenses,
       _uuid = uuid,
       _clock = clock;

  final AppDatabase _database;
  final PayrollDao _payrollDao;
  final ProfilesDao _profilesDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final PayrollExpenseSink _expenses;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static const String employeesTable = 'employees';
  static const String paymentsTable = 'payroll_payments';

  /// El módulo es **solo de Élite** (PRD §6). Se comprueba aquí y no solo en la
  /// interfaz, como exige `RS-02`.
  Future<bool> isAvailableFor(String ownerId) async {
    final profile = await _profilesDao.findById(ownerId);
    return SubscriptionPlan.fromId(profile?.plan) == SubscriptionPlan.elite;
  }

  // --- Empleados -----------------------------------------------------------

  Stream<List<Employee>> watchEmployees({required String ownerId, bool activeOnly = false}) =>
      _payrollDao
          .watchEmployees(ownerId: ownerId, activeOnly: activeOnly)
          .map((rows) => rows.map(Employee.fromRow).toList());

  Future<Employee?> findEmployee(String id) async {
    final row = await _payrollDao.findEmployee(id);
    return row == null ? null : Employee.fromRow(row);
  }

  Future<Result<Employee>> saveEmployee(Employee draft) async {
    if (draft.name.trim().isEmpty) {
      return const Err(ValidationFailure('name', debugMessage: 'el nombre es obligatorio'));
    }
    if (draft.salaryCents <= 0) {
      return const Err(
        ValidationFailure('salary', debugMessage: 'el salario debe ser mayor que 0'),
      );
    }
    if (!await isAvailableFor(draft.ownerId)) {
      return const Err(
        PlanLimitFailure(limit: 0, current: 0, debugMessage: 'empleomanía requiere Élite'),
      );
    }

    final now = _clock();
    final isNew = draft.id.isEmpty;
    final employee = Employee(
      id: isNew ? _uuid.v4() : draft.id,
      ownerId: draft.ownerId,
      name: draft.name.trim(),
      role: _trimToNull(draft.role),
      phone: _trimToNull(draft.phone),
      document: _trimToNull(draft.document),
      salaryCents: draft.salaryCents,
      frequency: draft.frequency,
      isActive: draft.isActive,
      createdAt: isNew ? now : draft.createdAt,
      updatedAt: now,
    );

    return guard(() async {
      await _database.transaction(() async {
        await _payrollDao.upsertEmployee(employee.toCompanion(dirty: true));
        await _syncQueue.enqueue(
          entityTable: employeesTable,
          entityId: employee.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(employee.toRemoteJson()),
          now: now,
        );
      });
      return employee;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Da de baja a un empleado sin borrarlo.
  ///
  /// Es lo que corresponde casi siempre: sus pagos ya hechos siguen contando en
  /// los meses en que se hicieron, y borrarlo dejaría esos gastos sin nombre.
  Future<Result<Employee>> setActive(String id, {required bool isActive}) async {
    final existing = await findEmployee(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'empleado no encontrado'));
    }

    final now = _clock();
    final updated = Employee(
      id: existing.id,
      ownerId: existing.ownerId,
      name: existing.name,
      role: existing.role,
      phone: existing.phone,
      document: existing.document,
      salaryCents: existing.salaryCents,
      frequency: existing.frequency,
      isActive: isActive,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    return guard(() async {
      await _database.transaction(() async {
        await _payrollDao.upsertEmployee(updated.toCompanion(dirty: true));
        await _syncQueue.enqueue(
          entityTable: employeesTable,
          entityId: updated.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(updated.toRemoteJson()),
          now: now,
        );
      });
      return updated;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  Future<Result<void>> deleteEmployee(String id) async {
    final existing = await _payrollDao.findEmployee(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'empleado no encontrado'));
    }

    final now = _clock();
    final deleted = Employee.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    return guard(() async {
      await _database.transaction(() async {
        await _payrollDao.softDeleteEmployee(id, now);
        await _syncQueue.enqueue(
          entityTable: employeesTable,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted),
          now: now,
        );
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  // --- Pagos ---------------------------------------------------------------

  Stream<List<PayrollPayment>> watchPayments({required String ownerId, String? employeeId}) =>
      _payrollDao
          .watchPayments(ownerId: ownerId, employeeId: employeeId)
          .map((rows) => rows.map(PayrollPayment.fromRow).toList());

  /// Costo mensual estimado de la plantilla — `RS-07`.
  ///
  /// Semanal × 4,33 · quincenal × 2 · mensual × 1. La cifra **se rotula como
  /// estimación** en la pantalla: nadie cobra 4,33 semanas en un mes concreto,
  /// y presentarla como exacta haría que el criador la cuadrara contra su banco
  /// y no le diera.
  Stream<PayrollSummary> watchSummary(String ownerId) {
    final now = _clock();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    return _payrollDao.watchEmployees(ownerId: ownerId, activeOnly: true).asyncMap((rows) async {
      final employees = rows.map(Employee.fromRow).toList();
      final payments = await _payrollDao.watchPayments(ownerId: ownerId).first;

      var paid = 0;
      for (final row in payments) {
        // Cuenta en el mes del cierre del período, que es cuando el pago se
        // devenga. Repartirlo entre meses complicaría el cierre sin aportar
        // nada: el gasto contable ya lleva su propia fecha.
        if (!row.periodEnd.isBefore(monthStart) && row.periodEnd.isBefore(monthEnd)) {
          paid += row.netCents;
        }
      }

      return PayrollSummary(
        activeCount: employees.length,
        monthlyCostCents: employees.fold(0, (sum, e) => sum + e.monthlyCostCents),
        paidThisMonthCents: paid,
      );
    });
  }

  /// Pagos vivos que se solapan con el período — advertencia de duplicado.
  Future<List<PayrollPayment>> overlappingPayments({
    required String employeeId,
    required DateTime start,
    required DateTime end,
    String? excludeId,
  }) async {
    final rows = await _payrollDao.overlapping(
      employeeId: employeeId,
      start: start,
      end: end,
      excludeId: excludeId,
    );
    return rows.map(PayrollPayment.fromRow).toList();
  }

  /// Confirma un pago — `RF-NOM-03` y `RS-06`.
  ///
  /// El pago y su gasto de nómina se escriben **en la misma transacción**: si
  /// el gasto falla, el pago no queda registrado. Lo contrario dejaría el mes
  /// cuadrando mal justo en el módulo que existe para que cuadre.
  Future<Result<PayrollPayment>> confirmPayment(PayrollPayment draft) async {
    // `RV-15` — el neto no puede ser negativo.
    if (draft.deductionsCents > draft.baseCents + draft.bonusCents) {
      return const Err(
        ValidationFailure('deductions', debugMessage: 'el neto no puede ser negativo'),
      );
    }
    if (draft.baseCents <= 0) {
      return const Err(ValidationFailure('base', debugMessage: 'la base debe ser mayor que 0'));
    }
    if (draft.periodEnd.isBefore(draft.periodStart)) {
      return const Err(ValidationFailure('period', debugMessage: 'el período está invertido'));
    }
    if (!await isAvailableFor(draft.ownerId)) {
      return const Err(
        PlanLimitFailure(limit: 0, current: 0, debugMessage: 'empleomanía requiere Élite'),
      );
    }

    final employee = await findEmployee(draft.employeeId);
    if (employee == null) {
      return const Err(NotFoundFailure(debugMessage: 'empleado no encontrado'));
    }

    final now = _clock();
    final id = draft.id.isEmpty ? _uuid.v4() : draft.id;

    return guard(() async {
      late PayrollPayment saved;

      await _database.transaction(() async {
        // El gasto primero: necesitamos su id para guardarlo en el pago, y si
        // falla no llegamos a escribir el pago. Drift anida transacciones con
        // savepoints, así que la del sink se une a esta en vez de abrir otra.
        final transactionId = await _expenses.recordPayrollExpense(
          ownerId: draft.ownerId,
          amountCents: draft.netCents,
          date: draft.periodEnd,
          description: employee.name,
          now: now,
        );

        saved = PayrollPayment(
          id: id,
          ownerId: draft.ownerId,
          employeeId: draft.employeeId,
          periodStart: draft.periodStart,
          periodEnd: draft.periodEnd,
          baseCents: draft.baseCents,
          bonusCents: draft.bonusCents,
          deductionsCents: draft.deductionsCents,
          method: draft.method,
          transactionId: transactionId,
          createdAt: draft.id.isEmpty ? now : draft.createdAt,
          updatedAt: now,
        );

        await _payrollDao.upsertPayment(saved.toCompanion(dirty: true));
        await _syncQueue.enqueue(
          entityTable: paymentsTable,
          entityId: saved.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(saved.toRemoteJson()),
          now: now,
        );
      });

      return saved;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Anula un pago y, con él, su gasto — `RS-06`.
  Future<Result<void>> voidPayment(String id) async {
    final existing = await _payrollDao.findPayment(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'pago no encontrado'));
    }

    final now = _clock();
    final payment = PayrollPayment.fromRow(existing);
    final deleted = payment.toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    return guard(() async {
      await _database.transaction(() async {
        await _payrollDao.softDeletePayment(id, now);
        await _syncQueue.enqueue(
          entityTable: paymentsTable,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted),
          now: now,
        );

        // Los dos juntos: un gasto de nómina sin su pago es dinero que el mes
        // resta y que el criador no puede explicar.
        final transactionId = payment.transactionId;
        if (transactionId != null) {
          await _expenses.voidPayrollExpense(transactionId: transactionId, now: now);
        }
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Propone el período que toca pagar a un empleado.
  ///
  /// Arranca donde terminó su último pago; si no tiene ninguno, cubre el
  /// período completo que acaba hoy. Es la diferencia entre teclear dos fechas
  /// o confirmar las que ya están puestas.
  Future<({DateTime start, DateTime end})> suggestPeriodFor(Employee employee) async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    final payments = await _payrollDao
        .watchPayments(ownerId: employee.ownerId, employeeId: employee.id)
        .first;

    if (payments.isNotEmpty) {
      final last = payments.first.periodEnd;
      final start = DateTime(last.year, last.month, last.day).add(const Duration(days: 1));
      return (start: start, end: _periodEnd(start, employee.frequency));
    }

    final days = employee.frequency.days;
    if (days == null) return (start: DateTime(today.year, today.month), end: today);
    return (start: today.subtract(Duration(days: days - 1)), end: today);
  }

  /// Fin del período que empieza en [start].
  static DateTime _periodEnd(DateTime start, PayFrequency frequency) {
    final days = frequency.days;
    if (days != null) return start.add(Duration(days: days - 1));

    // Mensual: hasta el día anterior en el mes siguiente, con el mismo cuidado
    // del desbordamiento que los recurrentes de contabilidad —un período que
    // empieza el 31 no puede terminar el 31 de un mes de treinta—.
    final totalMonths = start.month - 1 + 1;
    final year = start.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final sameDayNextMonth = DateTime(year, month, start.day > lastDay ? lastDay : start.day);
    return sameDayNextMonth.subtract(const Duration(days: 1));
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  // --- Sincronización ------------------------------------------------------

  /// Descarga de empleados. Va antes que la de pagos: un pago sin su empleado
  /// no se puede pintar.
  late final RemotePuller employeesPuller = _EmployeesPuller(this);
  late final RemotePuller paymentsPuller = _PaymentsPuller(this);

  Future<DateTime?> _pullEmployees({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    final query = _supabase.client.from(employeesTable).select().eq('owner_id', ownerId);
    final rows = since == null
        ? await query
        : await query.gt('updated_at', since.toUtc().toIso8601String());
    if (rows.isEmpty) return null;

    final pending = await _syncQueue.pendingIdsFor(employeesTable);

    DateTime? latest;
    final incoming = <EmployeesCompanion>[];
    for (final row in rows) {
      final employee = Employee.fromRemoteJson(row);
      if (latest == null || employee.updatedAt.isAfter(latest)) latest = employee.updatedAt;
      if (pending.contains(employee.id)) continue;
      incoming.add(employee.toCompanion());
    }

    if (incoming.isNotEmpty) await _payrollDao.upsertEmployees(incoming);
    return latest;
  }

  Future<DateTime?> _pullPayments({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    final query = _supabase.client.from(paymentsTable).select().eq('owner_id', ownerId);
    final rows = since == null
        ? await query
        : await query.gt('updated_at', since.toUtc().toIso8601String());
    if (rows.isEmpty) return null;

    final pending = await _syncQueue.pendingIdsFor(paymentsTable);

    DateTime? latest;
    final incoming = <PayrollPaymentsCompanion>[];
    for (final row in rows) {
      final payment = PayrollPayment.fromRemoteJson(row);
      if (latest == null || payment.updatedAt.isAfter(latest)) latest = payment.updatedAt;
      if (pending.contains(payment.id)) continue;
      incoming.add(payment.toCompanion());
    }

    if (incoming.isNotEmpty) await _payrollDao.upsertPayments(incoming);
    return latest;
  }
}

class _EmployeesPuller implements RemotePuller {
  _EmployeesPuller(this._repository);

  final PayrollRepository _repository;

  @override
  String get table => PayrollRepository.employeesTable;

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) =>
      _repository._pullEmployees(ownerId: ownerId, since: since);
}

class _PaymentsPuller implements RemotePuller {
  _PaymentsPuller(this._repository);

  final PayrollRepository _repository;

  @override
  String get table => PayrollRepository.paymentsTable;

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) =>
      _repository._pullPayments(ownerId: ownerId, since: since);
}
