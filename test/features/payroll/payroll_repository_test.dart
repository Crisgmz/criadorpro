import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/core/utils/validators.dart';
import 'package:criadorpro/features/accounting/model/transaction.dart';
import 'package:criadorpro/features/accounting/repository/transactions_repository.dart';
import 'package:criadorpro/features/payroll/model/employee.dart';
import 'package:criadorpro/features/payroll/model/payroll_payment.dart';
import 'package:criadorpro/features/payroll/repository/payroll_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-NOM` — empleomanía.
///
/// Lo que más se prueba es el puente con contabilidad (`RS-06`): un pago sin su
/// gasto, o un gasto sin su pago, descuadra el mes sin que nada falle a la
/// vista. Después, la aritmética del costo estimado (`RS-07`) y el neto
/// (`RV-15`).
void main() {
  late AppDatabase database;
  late TransactionsRepository accounting;
  late PayrollRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 15);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    accounting = TransactionsRepository(
      database: database,
      transactionsDao: database.transactionsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
    repository = PayrollRepository(
      database: database,
      payrollDao: database.payrollDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      expenses: accounting,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> givenPlan([SubscriptionPlan plan = SubscriptionPlan.elite]) =>
      database.profilesDao.upsert(
        ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now, plan: Value(plan.id)),
      );

  Employee draftEmployee({
    String name = 'Juan Pérez',
    int salaryCents = 800000,
    PayFrequency frequency = PayFrequency.biweekly,
    bool isActive = true,
  }) => Employee(
    id: '',
    ownerId: ownerId,
    name: name,
    salaryCents: salaryCents,
    frequency: frequency,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );

  Future<Employee> givenEmployee({
    String name = 'Juan Pérez',
    int salaryCents = 800000,
    PayFrequency frequency = PayFrequency.biweekly,
  }) async {
    final result = await repository.saveEmployee(
      draftEmployee(name: name, salaryCents: salaryCents, frequency: frequency),
    );
    return (result as Ok<Employee>).value;
  }

  PayrollPayment draftPayment(
    String employeeId, {
    int baseCents = 800000,
    int bonusCents = 0,
    int deductionsCents = 0,
    DateTime? start,
    DateTime? end,
  }) => PayrollPayment(
    id: '',
    ownerId: ownerId,
    employeeId: employeeId,
    periodStart: start ?? DateTime(2026, 8),
    periodEnd: end ?? DateTime(2026, 8, 15),
    baseCents: baseCents,
    bonusCents: bonusCents,
    deductionsCents: deductionsCents,
    method: PaymentMethod.cash,
    createdAt: now,
    updatedAt: now,
  );

  group('plan', () {
    test('el módulo es solo de Élite (PRD §6)', () async {
      await givenPlan(SubscriptionPlan.pro);

      final result = await repository.saveEmployee(draftEmployee());

      expect(result, isA<Err<Employee>>());
      expect((result as Err<Employee>).failure, isA<PlanLimitFailure>());
    });

    test('con Élite se puede registrar', () async {
      await givenPlan();
      expect(await repository.saveEmployee(draftEmployee()), isA<Ok<Employee>>());
    });
  });

  group('RS-06 · el pago y su gasto van juntos', () {
    test('confirmar un pago crea el gasto de nómina por el neto', () async {
      await givenPlan();
      final employee = await givenEmployee();

      final result = await repository.confirmPayment(
        draftPayment(employee.id, baseCents: 800000, bonusCents: 50000, deductionsCents: 30000),
      );

      final payment = (result as Ok<PayrollPayment>).value;
      expect(payment.netCents, 820000);
      expect(payment.transactionId, isNotNull);

      final expense = await database.transactionsDao.findById(payment.transactionId!);
      expect(expense, isNotNull);
      expect(expense!.category, TransactionCategory.payroll.id);
      expect(expense.type, TransactionType.expense.id);
      // El gasto vale el neto, no la base: es el dinero que salió del criadero.
      expect(expense.amountCents, 820000);
      // Se ancla al cierre del período, que es cuando el pago se devenga.
      expect(expense.date, payment.periodEnd);
    });

    test('anular el pago anula también el gasto', () async {
      await givenPlan();
      final employee = await givenEmployee();
      final payment = (await repository.confirmPayment(draftPayment(employee.id)) as Ok).value;

      expect(await repository.voidPayment(payment.id), isA<Ok<void>>());

      final expense = await database.transactionsDao.findById(payment.transactionId!);
      expect(expense!.isDeleted, isTrue, reason: 'un gasto sin su pago descuadra el mes');
    });

    test('anular un pago cuyo gasto ya no existe no falla', () async {
      await givenPlan();
      final employee = await givenEmployee();
      final payment = (await repository.confirmPayment(draftPayment(employee.id)) as Ok).value;

      // Lo borró otro dispositivo: el estado final que se buscaba ya está.
      await database.transactionsDao.softDelete(payment.transactionId!, now);

      expect(await repository.voidPayment(payment.id), isA<Ok<void>>());
    });

    test('si el pago no se puede guardar, el gasto no queda suelto', () async {
      await givenPlan();

      // Empleado inexistente: la comprobación va antes de abrir la transacción,
      // así que no debe llegar a escribirse ningún gasto.
      final result = await repository.confirmPayment(draftPayment('no-existe'));

      expect((result as Err).failure, isA<NotFoundFailure>());
      final expenses = await database.transactionsDao
          .watchMonth(ownerId: ownerId, month: DateTime(2026, 8))
          .first;
      expect(expenses, isEmpty);
    });

    test('el gasto de nómina sigue sin poder crearse a mano', () async {
      await givenPlan();

      final result = await accounting.save(
        Transaction(
          id: '',
          ownerId: ownerId,
          type: TransactionType.expense,
          category: TransactionCategory.payroll,
          amountCents: 100000,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect((result as Err).failure, isA<ValidationFailure>());
    });
  });

  group('RV-15 · el neto no puede ser negativo', () {
    test('deducciones mayores que base más bono se rechazan', () async {
      await givenPlan();
      final employee = await givenEmployee();

      final result = await repository.confirmPayment(
        draftPayment(employee.id, baseCents: 100000, bonusCents: 20000, deductionsCents: 130000),
      );

      expect((result as Err).failure, isA<ValidationFailure>());
    });

    test('deducciones exactamente iguales al total dan neto cero y se aceptan', () async {
      await givenPlan();
      final employee = await givenEmployee();

      final result = await repository.confirmPayment(
        draftPayment(employee.id, baseCents: 100000, bonusCents: 20000, deductionsCents: 120000),
      );

      expect((result as Ok<PayrollPayment>).value.netCents, 0);
    });
  });

  group('RS-07 · costo mensual estimado', () {
    test('normaliza semanal ×4,33 · quincenal ×2 · mensual ×1', () async {
      await givenPlan();
      await givenEmployee(name: 'Semanal', salaryCents: 300000, frequency: PayFrequency.weekly);
      await givenEmployee(name: 'Quincenal', salaryCents: 800000, frequency: PayFrequency.biweekly);
      await givenEmployee(name: 'Mensual', salaryCents: 2500000, frequency: PayFrequency.monthly);

      final summary = await repository.watchSummary(ownerId).first;

      // 3.000 × 52/12 = 13.000 · 8.000 × 2 = 16.000 · 25.000 × 1 = 25.000
      expect(summary.activeCount, 3);
      expect(summary.monthlyCostCents, 1300000 + 1600000 + 2500000);
    });

    test('quien está de baja deja de sumar, pero no se borra', () async {
      await givenPlan();
      final employee = await givenEmployee(salaryCents: 800000);

      await repository.setActive(employee.id, isActive: false);

      final summary = await repository.watchSummary(ownerId).first;
      expect(summary.activeCount, 0);
      expect(summary.monthlyCostCents, 0);

      // `RS-03`: sigue consultable.
      final all = await repository.watchEmployees(ownerId: ownerId).first;
      expect(all, hasLength(1));
    });

    test('lo pagado en el mes se cuenta aparte de la estimación', () async {
      await givenPlan();
      final employee = await givenEmployee();
      await repository.confirmPayment(draftPayment(employee.id, baseCents: 800000));

      final summary = await repository.watchSummary(ownerId).first;
      expect(summary.paidThisMonthCents, 800000);
    });
  });

  group('período', () {
    test('advierte del solapamiento con un pago ya registrado', () async {
      await givenPlan();
      final employee = await givenEmployee();
      await repository.confirmPayment(
        draftPayment(employee.id, start: DateTime(2026, 8), end: DateTime(2026, 8, 15)),
      );

      // Un período contenido dentro del anterior también solapa: comparar solo
      // los inicios lo dejaría pasar.
      final overlapping = await repository.overlappingPayments(
        employeeId: employee.id,
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 8, 10),
      );

      expect(overlapping, hasLength(1));
    });

    test('propone el período siguiente al último pagado', () async {
      await givenPlan();
      final employee = await givenEmployee(frequency: PayFrequency.biweekly);
      await repository.confirmPayment(
        draftPayment(employee.id, start: DateTime(2026, 8), end: DateTime(2026, 8, 15)),
      );

      final period = await repository.suggestPeriodFor(employee);

      expect(period.start, DateTime(2026, 8, 16));
      expect(period.end, DateTime(2026, 8, 30));
    });

    test('sin pagos previos propone el período que termina hoy', () async {
      await givenPlan();
      final employee = await givenEmployee(frequency: PayFrequency.weekly);

      final period = await repository.suggestPeriodFor(employee);

      expect(period.end, DateTime(2026, 8, 15));
      expect(period.start, DateTime(2026, 8, 9));
    });
  });

  group('RV-17 · cédula dominicana', () {
    test('acepta una cédula con dígito verificador correcto', () {
      // 001-0100000-8, con el dígito verificador que le corresponde.
      expect(Validators.isValidDominicanId('00101000008'), isTrue);
      expect(Validators.isValidDominicanId('402-0123456-0'), isTrue, reason: 'con guiones también');
    });

    test('rechaza una con el verificador cambiado', () {
      expect(Validators.isValidDominicanId('00101000001'), isFalse);
    });

    test('rechaza longitudes distintas de once', () {
      expect(Validators.isValidDominicanId('0010100000'), isFalse);
    });

    test('no bloquea el alta: el empleado se guarda igual', () async {
      await givenPlan();

      final result = await repository.saveEmployee(
        Employee(
          id: '',
          ownerId: ownerId,
          name: 'Sin documento válido',
          document: '12345678901',
          salaryCents: 500000,
          frequency: PayFrequency.monthly,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result, isA<Ok<Employee>>());
    });
  });

  test('cada escritura encola su operación de sincronización', () async {
    await givenPlan();
    final employee = await givenEmployee();
    await repository.confirmPayment(draftPayment(employee.id));

    final pending = await database.syncQueueDao.pending(maxAttempts: 5);
    final tables = pending.map((entry) => entry.entityTable).toSet();

    expect(tables, containsAll(<String>{'employees', 'payroll_payments', 'transactions'}));
  });
}
