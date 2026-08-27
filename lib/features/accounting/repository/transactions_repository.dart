import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/accounting/payroll_expense_sink.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/db/daos/transactions_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../model/transaction.dart';

/// Contabilidad — `RF-CON`.
///
/// Todos los totales salen de la base local (`RF-CON-08`): el criador cierra su
/// mes sentado donde no hay señal.
class TransactionsRepository implements RemotePuller, PayrollExpenseSink {
  TransactionsRepository({
    required AppDatabase database,
    required TransactionsDao transactionsDao,
    required ProfilesDao profilesDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _transactionsDao = transactionsDao,
       _profilesDao = profilesDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _uuid = uuid,
       _clock = clock;

  final AppDatabase _database;
  final TransactionsDao _transactionsDao;
  final ProfilesDao _profilesDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  String get table => 'transactions';

  Stream<List<Transaction>> watchMonth({required String ownerId, required DateTime month}) =>
      _transactionsDao
          .watchMonth(ownerId: ownerId, month: month)
          .map((rows) => rows.map(Transaction.fromRow).toList());

  /// `RF-CON-04` y `RF-CON-06` — totales del mes y desglose por categoría.
  ///
  /// Se suma en centavos enteros y no en coma flotante: sobre dos mil
  /// movimientos, el error de redondeo de `double` llega a verse en el balance.
  Stream<MonthlyBalance> watchBalance({required String ownerId, required DateTime month}) =>
      _transactionsDao.watchMonth(ownerId: ownerId, month: month).map((rows) {
        var income = 0;
        var expense = 0;
        final byCategory = <TransactionCategory, int>{};

        for (final row in rows) {
          final type = TransactionType.fromId(row.type);
          final category = TransactionCategory.fromId(row.category);

          if (type == TransactionType.income) {
            income += row.amountCents;
          } else {
            expense += row.amountCents;
          }
          byCategory[category] = (byCategory[category] ?? 0) + row.amountCents;
        }

        return MonthlyBalance(
          month: DateTime(month.year, month.month),
          incomeCents: income,
          expenseCents: expense,
          byCategory: byCategory,
        );
      });

  /// Meses con movimientos — `RF-CON-05`.
  Future<List<DateTime>> monthsWithData(String ownerId) => _transactionsDao.monthsWithData(ownerId);

  /// El módulo es de Pro en adelante (PRD §6). Se comprueba aquí y no solo en
  /// la interfaz, como exige `RS-02`.
  Future<bool> isAvailableFor(String ownerId) async {
    final profile = await _profilesDao.findById(ownerId);
    return SubscriptionPlan.fromId(profile?.plan) != SubscriptionPlan.free;
  }

  Future<Result<Transaction>> save(Transaction draft) async {
    // El SRS es explícito: `amount numeric(12,2) > 0`. El signo lo pone el
    // tipo, no el importe — un gasto negativo sumaría al balance.
    if (draft.amountCents <= 0) {
      return const Err(
        ValidationFailure('amount', debugMessage: 'el importe debe ser mayor que 0'),
      );
    }

    // `RF-CON-02`: la categoría tiene que pertenecer al tipo. Un «alimento»
    // marcado como ingreso rompería el desglose de la pantalla 31.
    if (draft.category.type != draft.type) {
      return const Err(
        ValidationFailure('category', debugMessage: 'la categoría no es de ese tipo'),
      );
    }

    // `payroll` la escribe el módulo de empleomanía (`RS-06`), no el criador.
    if (draft.category.isSystemOnly && draft.recurrenceSourceId == null && draft.id.isEmpty) {
      return const Err(
        ValidationFailure('category', debugMessage: 'categoría de uso exclusivo del sistema'),
      );
    }

    final now = _clock();
    if (draft.date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59))) {
      return const Err(ValidationFailure('date', debugMessage: 'fecha futura'));
    }

    if (!await isAvailableFor(draft.ownerId)) {
      return const Err(
        PlanLimitFailure(limit: 0, current: 0, debugMessage: 'contabilidad requiere Pro'),
      );
    }

    final isNew = draft.id.isEmpty;
    final transaction = Transaction(
      id: isNew ? _uuid.v4() : draft.id,
      ownerId: draft.ownerId,
      type: draft.type,
      category: draft.category,
      amountCents: draft.amountCents,
      date: draft.date,
      description: _trimToNull(draft.description),
      birdId: draft.birdId,
      recurrence: draft.recurrence,
      recurrenceSourceId: draft.recurrenceSourceId,
      createdAt: isNew ? now : draft.createdAt,
      updatedAt: now,
    );

    return guard(() async {
      await _persist(transaction, now);
      return transaction;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  Future<Result<void>> delete(String id) async {
    final existing = await _transactionsDao.findById(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'transaction no encontrada'));
    }

    final now = _clock();
    final deleted = Transaction.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    return guard(() async {
      await _database.transaction(() async {
        await _transactionsDao.softDelete(id, now);
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted),
          now: now,
        );
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  /// Genera los movimientos recurrentes vencidos — `RF-CON-03` y `RS-08`.
  ///
  /// Se llama al abrir la app. Recorre cada plantilla, calcula qué períodos han
  /// vencido desde su fecha y crea los que falten. **No duplica**: antes de
  /// crear comprueba qué fechas ya se generaron para esa plantilla, así que
  /// abrir la app cinco veces el mismo día no cambia nada.
  ///
  /// Devuelve cuántos movimientos se crearon.
  Future<int> generateDueRecurrences(String ownerId) async {
    if (!await isAvailableFor(ownerId)) return 0;

    final templates = await _transactionsDao.recurringTemplates(ownerId);
    if (templates.isEmpty) return 0;

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    var created = 0;

    for (final row in templates) {
      final template = Transaction.fromRow(row);
      final existing = (await _transactionsDao.generatedDatesFor(
        template.id,
      )).map((d) => DateTime(d.year, d.month, d.day)).toSet();

      for (final date in _dueDates(template, until: today)) {
        if (existing.contains(date)) continue;

        final generated = Transaction(
          id: _uuid.v4(),
          ownerId: template.ownerId,
          type: template.type,
          category: template.category,
          amountCents: template.amountCents,
          date: date,
          description: template.description,
          birdId: template.birdId,
          // La copia no es recurrente: si lo fuera, generaría copias de sí
          // misma y la serie crecería sin control.
          recurrence: Recurrence.none,
          recurrenceSourceId: template.id,
          createdAt: now,
          updatedAt: now,
        );

        await _persist(generated, now);
        created++;
      }
    }

    return created;
  }

  /// Fechas vencidas de una plantilla, sin incluir la suya propia.
  List<DateTime> _dueDates(Transaction template, {required DateTime until}) {
    final dates = <DateTime>[];
    final start = DateTime(template.date.year, template.date.month, template.date.day);

    if (template.recurrence == Recurrence.monthly) {
      // Por calendario y no por días: «cada mes» significa el mismo día del mes
      // siguiente, no treinta días después.
      var offset = 1;
      while (true) {
        final next = _addMonths(start, offset);
        if (next.isAfter(until)) break;
        dates.add(next);
        offset++;
      }
      return dates;
    }

    final step = template.recurrence.days;
    if (step == null) return dates;

    var next = start.add(Duration(days: step));
    while (!next.isAfter(until)) {
      dates.add(DateTime(next.year, next.month, next.day));
      next = next.add(Duration(days: step));
    }
    return dates;
  }

  /// Suma meses respetando el calendario.
  ///
  /// No vale `DateTime(año, mes + n, día)`: con un día 31, los meses que no lo
  /// tienen se **desbordan al siguiente** —el 31 de junio se convierte en 1 de
  /// julio—, y una serie mensual acabaría saltándose junio y generando dos
  /// movimientos en julio. Como en cualquier domiciliación, «el 31» en un mes
  /// de treinta días significa el último día de ese mes.
  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;

    // El día 0 del mes siguiente es el último del mes actual.
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDayOfMonth ? lastDayOfMonth : date.day);
  }

  /// `RS-06` — gasto de nómina generado al confirmar un pago.
  ///
  /// No pasa por `save()` a propósito: `save()` rechaza la categoría `payroll`
  /// porque el criador no puede elegirla a mano, y esa comprobación tiene que
  /// seguir en pie. Este camino es el único que la escribe, y solo lo alcanza
  /// empleomanía a través de `PayrollExpenseSink`.
  ///
  /// Tampoco comprueba el plan: quien lo comprueba es el módulo que llama, y
  /// empleomanía es de Élite, que ya incluye contabilidad. Comprobarlo aquí
  /// abriría la puerta a un pago confirmado con su gasto rechazado — el
  /// escenario que `RS-06` existe para evitar.
  @override
  Future<String> recordPayrollExpense({
    required String ownerId,
    required int amountCents,
    required DateTime date,
    required String description,
    required DateTime now,
  }) async {
    final expense = Transaction(
      id: _uuid.v4(),
      ownerId: ownerId,
      type: TransactionType.expense,
      category: TransactionCategory.payroll,
      amountCents: amountCents,
      date: date,
      description: description,
      createdAt: now,
      updatedAt: now,
    );

    await _persist(expense, now);
    return expense.id;
  }

  @override
  Future<void> voidPayrollExpense({required String transactionId, required DateTime now}) async {
    final existing = await _transactionsDao.findById(transactionId);
    // Ya no está: lo borró otro dispositivo y el estado final es el que se
    // buscaba. Fallar aquí dejaría el pago sin anular por algo que ya está bien.
    if (existing == null || existing.isDeleted) return;

    final deleted = Transaction.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    await _transactionsDao.softDelete(transactionId, now);
    await _syncQueue.enqueue(
      entityTable: table,
      entityId: transactionId,
      operation: SyncOperation.delete,
      payload: jsonEncode(deleted),
      now: now,
    );
  }

  Future<void> _persist(Transaction transaction, DateTime now) => _database.transaction(() async {
    await _transactionsDao.upsert(transaction.toCompanion(dirty: true));
    await _syncQueue.enqueue(
      entityTable: table,
      entityId: transaction.id,
      operation: SyncOperation.upsert,
      payload: jsonEncode(transaction.toRemoteJson()),
      now: now,
    );
  });

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    final query = _supabase.client.from(table).select().eq('owner_id', ownerId);
    final rows = since == null
        ? await query
        : await query.gt('updated_at', since.toUtc().toIso8601String());

    if (rows.isEmpty) return null;

    final pending = await _syncQueue.pendingIdsFor(table);

    DateTime? latest;
    final incoming = <TransactionsCompanion>[];
    for (final row in rows) {
      final transaction = Transaction.fromRemoteJson(row);
      if (latest == null || transaction.updatedAt.isAfter(latest)) latest = transaction.updatedAt;
      if (pending.contains(transaction.id)) continue;
      incoming.add(transaction.toCompanion());
    }

    if (incoming.isNotEmpty) await _transactionsDao.upsertAll(incoming);
    return latest;
  }
}
