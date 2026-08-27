import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/weight_entries.dart';

part 'weights_dao.g.dart';

@DriftAccessor(tables: [WeightEntries])
class WeightsDao extends DatabaseAccessor<AppDatabase> with _$WeightsDaoMixin {
  WeightsDao(super.db);

  /// Historial de un ejemplar, lo más reciente primero — `RF-REG-14`.
  Stream<List<WeightEntryRow>> watchForBird(String birdId) =>
      (select(weightEntries)
            ..where((t) => t.birdId.equals(birdId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .watch();

  /// El más reciente, que es el que va a `birds.weight_g` y a la lista.
  ///
  /// Se ordena también por `created_at`: dos pesadas el mismo día son posibles
  /// —una al amanecer y otra tras la prueba— y sin el desempate el «actual»
  /// dependería del orden en que SQLite devolviera las filas.
  Future<WeightEntryRow?> latestForBird(String birdId) =>
      (select(weightEntries)
            ..where((t) => t.birdId.equals(birdId) & t.isDeleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<WeightEntryRow?> findById(String id) =>
      (select(weightEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// La entrada que generó una prueba de campo — `RF-PRU-07`.
  ///
  /// Es lo que hace idempotente el registro: editar la prueba actualiza esta
  /// fila en vez de añadir otra pesada que nadie hizo.
  Future<WeightEntryRow?> findByEvaluation(String evaluationId) =>
      (select(weightEntries)
            ..where((t) => t.evaluationId.equals(evaluationId) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<void> upsert(WeightEntriesCompanion entry) =>
      into(weightEntries).insertOnConflictUpdate(entry);

  Future<void> upsertAll(List<WeightEntriesCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(weightEntries, rows);
  });

  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(weightEntries)..where((t) => t.id.equals(id))).write(
        WeightEntriesCompanion(
          isDeleted: const Value(true),
          isDirty: const Value(true),
          updatedAt: Value(deletedAt),
        ),
      );

  Future<void> clear() => delete(weightEntries).go();
}
