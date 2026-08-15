import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/accounting/model/transaction.dart';
import 'package:criadorpro/features/accounting/repository/transactions_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-CON` — contabilidad. Lo que más se prueba es la aritmética del dinero y
/// la generación de recurrentes: un céntimo perdido por movimiento o una
/// duplicación silenciosa descuadran el mes sin que nada falle.
void main() {
  late AppDatabase database;
  late TransactionsRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 15);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TransactionsRepository(
      database: database,
      transactionsDao: database.transactionsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> givenPlan([SubscriptionPlan plan = SubscriptionPlan.pro]) =>
      database.profilesDao.upsert(
        ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now, plan: Value(plan.id)),
      );

  Transaction draft({
    TransactionType type = TransactionType.expense,
    TransactionCategory category = TransactionCategory.feed,
    int cents = 100000,
    DateTime? date,
    Recurrence recurrence = Recurrence.none,
    String? description,
  }) => Transaction(
    id: '',
    ownerId: ownerId,
    type: type,
    category: category,
    amountCents: cents,
    date: date ?? DateTime(2026, 8, 10),
    recurrence: recurrence,
    description: description,
    createdAt: now,
    updatedAt: now,
  );

  group('RF-CON-01 / RF-CON-02 · registro', () {
    test('guarda tipo, categoría, importe, fecha y descripción', () async {
      await givenPlan();

      final saved =
          ((await repository.save(draft(cents: 245050, description: '  Saco de maíz  ')))
                  as Ok<Transaction>)
              .value;

      expect(saved.amountCents, 245050);
      expect(saved.amount, 2450.50);
      expect(saved.description, 'Saco de maíz');
    });

    test('el importe tiene que ser mayor que cero', () async {
      await givenPlan();

      for (final cents in [0, -500]) {
        final result = await repository.save(draft(cents: cents));
        expect(((result as Err).failure as ValidationFailure).field, 'amount');
      }
    });

    test('RF-CON-02 · la categoría debe pertenecer al tipo', () async {
      await givenPlan();

      // «Alimento» es un gasto: como ingreso rompería el desglose del mes.
      final result = await repository.save(
        draft(type: TransactionType.income, category: TransactionCategory.feed),
      );

      expect(((result as Err).failure as ValidationFailure).field, 'category');
    });

    test('RS-06 · la categoría de nómina no se puede elegir a mano', () async {
      await givenPlan();

      final result = await repository.save(draft(category: TransactionCategory.payroll));

      expect(((result as Err).failure as ValidationFailure).field, 'category');
      // Y tampoco aparece en el selector.
      expect(
        TransactionCategory.selectableFor(TransactionType.expense),
        isNot(contains(TransactionCategory.payroll)),
      );
    });

    test('el catálogo de categorías está cerrado y repartido por tipo', () async {
      expect(TransactionCategory.selectableFor(TransactionType.income), hasLength(4));
      // Ocho de gasto menos la de nómina, que es del sistema.
      expect(TransactionCategory.selectableFor(TransactionType.expense), hasLength(7));
    });

    test('la fecha no puede ser futura', () async {
      await givenPlan();

      final result = await repository.save(draft(date: now.add(const Duration(days: 1))));

      expect(((result as Err).failure as ValidationFailure).field, 'date');
    });
  });

  group('el dinero se guarda en centavos', () {
    test('un importe con decimales no pierde céntimos al convertirse', () {
      // `12.45 * 100` da 1244.9999… en coma flotante: truncar perdería un
      // céntimo por movimiento.
      expect(Transaction.centsOf(12.45), 1245);
      expect(Transaction.centsOf(0.1), 10);
      expect(Transaction.centsOf(1234567.89), 123456789);
    });

    test('el balance de muchos movimientos cuadra al céntimo', () async {
      await givenPlan();
      // Cien movimientos de 0,10: en `double` la suma daría 10.000000000000002.
      for (var i = 0; i < 100; i++) {
        await repository.save(draft(cents: 10, date: DateTime(2026, 8, 3)));
      }

      final balance = await repository
          .watchBalance(ownerId: ownerId, month: DateTime(2026, 8))
          .first;

      expect(balance.expenseCents, 1000);
      expect(balance.expense, 10.0);
    });
  });

  group('RF-CON-04 / RF-CON-05 · cierre del mes', () {
    test('ingresos, gastos y balance del mes seleccionado', () async {
      await givenPlan();
      await repository.save(
        draft(type: TransactionType.income, category: TransactionCategory.birdSale, cents: 500000),
      );
      await repository.save(draft(cents: 120000));
      await repository.save(draft(cents: 80000));

      final balance = await repository
          .watchBalance(ownerId: ownerId, month: DateTime(2026, 8))
          .first;

      expect(balance.incomeCents, 500000);
      expect(balance.expenseCents, 200000);
      expect(balance.balanceCents, 300000);
      expect(balance.isNegative, isFalse);
    });

    test('un mes en pérdidas se marca negativo, sin más', () async {
      await givenPlan();
      await repository.save(draft(cents: 300000));

      final balance = await repository
          .watchBalance(ownerId: ownerId, month: DateTime(2026, 8))
          .first;

      // `RF-CON-04`: en rojo y sin mensajes adicionales. Perder dinero un mes
      // es información, no un error que haya que explicarle al criador.
      expect(balance.isNegative, isTrue);
      expect(balance.balanceCents, -300000);
    });

    test('cada mes cuenta solo lo suyo', () async {
      await givenPlan();
      await repository.save(draft(cents: 10000, date: DateTime(2026, 7, 31)));
      await repository.save(draft(cents: 20000, date: DateTime(2026, 8, 1)));

      final julio = await repository.watchBalance(ownerId: ownerId, month: DateTime(2026, 7)).first;
      final agosto = await repository
          .watchBalance(ownerId: ownerId, month: DateTime(2026, 8))
          .first;

      expect(julio.expenseCents, 10000);
      expect(agosto.expenseCents, 20000);
    });

    test('un movimiento del último día del mes con hora sí cuenta', () async {
      await givenPlan();
      // Comparar contra «último día a medianoche» lo dejaría fuera.
      await repository.save(draft(cents: 5000, date: DateTime(2026, 7, 31, 22, 30)));

      final balance = await repository
          .watchBalance(ownerId: ownerId, month: DateTime(2026, 7))
          .first;

      expect(balance.expenseCents, 5000);
    });

    test('RF-CON-05 · los meses con datos salen de más reciente a más antiguo', () async {
      await givenPlan();
      await repository.save(draft(date: DateTime(2026, 3, 4)));
      await repository.save(draft(date: DateTime(2026, 8, 4)));
      await repository.save(draft(date: DateTime(2026, 5, 4)));
      await repository.save(draft(date: DateTime(2026, 8, 20)));

      final months = await repository.monthsWithData(ownerId);

      expect(months.map((m) => m.month), [8, 5, 3]);
    });

    test('RF-CON-06 · el desglose reparte el mes por categoría', () async {
      await givenPlan();
      await repository.save(draft(category: TransactionCategory.feed, cents: 75000));
      await repository.save(draft(category: TransactionCategory.medicine, cents: 25000));

      final balance = await repository
          .watchBalance(ownerId: ownerId, month: DateTime(2026, 8))
          .first;

      expect(balance.byCategory[TransactionCategory.feed], 75000);
      expect(balance.shareOf(TransactionCategory.feed), 0.75);
      expect(balance.shareOf(TransactionCategory.medicine), 0.25);
      // Una categoría sin movimientos no rompe la división.
      expect(balance.shareOf(TransactionCategory.transport), 0);
    });
  });

  group('RS-08 · movimientos recurrentes', () {
    test('genera los períodos vencidos desde la plantilla', () async {
      await givenPlan();
      // Mensual desde el 15 de mayo; hoy es 15 de agosto → junio, julio, agosto.
      await repository.save(
        draft(date: DateTime(2026, 5, 15), recurrence: Recurrence.monthly, cents: 50000),
      );

      final created = await repository.generateDueRecurrences(ownerId);

      expect(created, 3);
      for (final month in [6, 7, 8]) {
        final balance = await repository
            .watchBalance(ownerId: ownerId, month: DateTime(2026, month))
            .first;
        expect(balance.expenseCents, 50000, reason: 'mes $month');
      }
    });

    test('abrir la app dos veces no duplica nada', () async {
      await givenPlan();
      await repository.save(draft(date: DateTime(2026, 6, 15), recurrence: Recurrence.monthly));

      final first = await repository.generateDueRecurrences(ownerId);
      final second = await repository.generateDueRecurrences(ownerId);
      final third = await repository.generateDueRecurrences(ownerId);

      expect(first, 2);
      expect(second, 0);
      expect(third, 0);
    });

    test('las copias no son recurrentes: la serie no se multiplica', () async {
      await givenPlan();
      await repository.save(draft(date: DateTime(2026, 7, 1), recurrence: Recurrence.weekly));

      await repository.generateDueRecurrences(ownerId);
      final templates = await database.transactionsDao.recurringTemplates(ownerId);

      // Si las copias heredaran la recurrencia, generarían copias de sí mismas.
      expect(templates, hasLength(1));
    });

    test('el semanal cuenta de siete en siete', () async {
      await givenPlan();
      // Del 1 al 15 de agosto: 8 y 15.
      await repository.save(draft(date: DateTime(2026, 8, 1), recurrence: Recurrence.weekly));

      final created = await repository.generateDueRecurrences(ownerId);

      expect(created, 2);
    });

    test('un movimiento sin recurrencia no genera nada', () async {
      await givenPlan();
      await repository.save(draft(date: DateTime(2026, 1, 1)));

      expect(await repository.generateDueRecurrences(ownerId), 0);
    });

    test('un mensual del día 31 no se salta los meses de treinta', () async {
      await givenPlan();
      // Junio no tiene 31. Con `DateTime(2026, 6, 31)` el resultado se desborda
      // al 1 de julio: la serie se saltaría junio y pondría dos movimientos en
      // julio. Como en cualquier domiciliación, debe caer el día 30.
      await repository.save(draft(date: DateTime(2026, 5, 31), recurrence: Recurrence.monthly));

      final created = await repository.generateDueRecurrences(ownerId);

      // Junio y julio; agosto todavía no ha vencido (hoy es día 15).
      expect(created, 2);

      final junio = await repository.watchMonth(ownerId: ownerId, month: DateTime(2026, 6)).first;
      expect(junio.single.date.day, 30);

      final julio = await repository.watchMonth(ownerId: ownerId, month: DateTime(2026, 7)).first;
      expect(julio.single.date.day, 31);
    });
  });

  group('restricción de plan', () {
    test('el plan gratuito no puede registrar movimientos', () async {
      await givenPlan(SubscriptionPlan.free);

      final result = await repository.save(draft());

      expect((result as Err<Transaction>).failure, isA<PlanLimitFailure>());
      expect(await repository.isAvailableFor(ownerId), isFalse);
    });

    test('ni se le generan recurrentes', () async {
      await givenPlan();
      await repository.save(draft(date: DateTime(2026, 5, 15), recurrence: Recurrence.monthly));

      // Degradar a gratuito: `RS-03` conserva los registros pero no deja crear.
      await givenPlan(SubscriptionPlan.free);

      expect(await repository.generateDueRecurrences(ownerId), 0);
    });
  });
}
