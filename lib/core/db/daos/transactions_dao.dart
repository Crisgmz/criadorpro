import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transactions.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase> with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Movimientos de un mes — pantalla 29.
  ///
  /// El rango se calcula como `[primer día, primer día del mes siguiente)`, un
  /// intervalo semiabierto: comparar contra «último día del mes» dejaría fuera
  /// cualquier movimiento con hora distinta de medianoche.
  Stream<List<TransactionRow>> watchMonth({required String ownerId, required DateTime month}) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    return (select(transactions)
          ..where(
            (t) =>
                t.ownerId.equals(ownerId) &
                t.isDeleted.equals(false) &
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Meses que tienen movimientos, para que la navegación de `RF-CON-05` no
  /// ofrezca períodos vacíos.
  Future<List<DateTime>> monthsWithData(String ownerId) async {
    final rows = await (select(
      transactions,
    )..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false))).get();

    // Se agrupa en Dart y no en SQL: las fechas se guardan como marca de tiempo
    // y `strftime` las interpretaría en UTC, corriendo de mes los movimientos
    // registrados de noche en República Dominicana.
    final months = <DateTime>{for (final row in rows) DateTime(row.date.year, row.date.month)};
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Future<TransactionRow?> findById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Plantillas recurrentes vivas — `RS-08`.
  Future<List<TransactionRow>> recurringTemplates(String ownerId) =>
      (select(transactions)..where(
            (t) =>
                t.ownerId.equals(ownerId) &
                t.isDeleted.equals(false) &
                t.recurrence.equals('none').not() &
                t.recurrenceSourceId.isNull(),
          ))
          .get();

  /// Fechas ya generadas para una plantilla. Es lo que evita duplicar cuando la
  /// app se abre dos veces el mismo día.
  Future<List<DateTime>> generatedDatesFor(String templateId) async {
    final rows = await (select(
      transactions,
    )..where((t) => t.recurrenceSourceId.equals(templateId))).get();
    return rows.map((row) => row.date).toList();
  }

  Future<void> upsert(TransactionsCompanion transaction) =>
      into(transactions).insertOnConflictUpdate(transaction);

  Future<void> upsertAll(List<TransactionsCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(transactions, rows);
  });

  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          isDeleted: const Value(true),
          isDirty: const Value(true),
          updatedAt: Value(deletedAt),
        ),
      );

  Future<void> clear() => delete(transactions).go();
}
