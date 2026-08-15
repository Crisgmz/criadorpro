import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/evaluations.dart';

part 'evaluations_dao.g.dart';

@DriftAccessor(tables: [Evaluations])
class EvaluationsDao extends DatabaseAccessor<AppDatabase> with _$EvaluationsDaoMixin {
  EvaluationsDao(super.db);

  /// Historial del criadero, lo más reciente primero — pantalla 24.
  Stream<List<EvaluationRow>> watchAll({required String ownerId, String? result}) {
    final query = select(evaluations)
      ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false));

    // `RF-PRU-04` — filtro por resultado.
    if (result != null) query.where((t) => t.result.equals(result));

    query.orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]);
    return query.watch();
  }

  /// `RF-PRU-05` — solo las pruebas de un ejemplar, para su ficha.
  Stream<List<EvaluationRow>> watchForBird(String birdId) =>
      (select(evaluations)
            ..where((t) => t.birdId.equals(birdId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .watch();

  Future<EvaluationRow?> findById(String id) =>
      (select(evaluations)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Todas las pruebas vivas del criadero, para calcular las estadísticas de
  /// `RF-PRU-03` en una sola lectura en lugar de tres consultas agregadas.
  Stream<List<EvaluationRow>> watchForStats(String ownerId) => (select(
    evaluations,
  )..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false))).watch();

  Future<void> upsert(EvaluationsCompanion evaluation) =>
      into(evaluations).insertOnConflictUpdate(evaluation);

  Future<void> upsertAll(List<EvaluationsCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(evaluations, rows);
  });

  /// Borrado lógico: se propaga al resto de dispositivos (`RS-10`).
  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(evaluations)..where((t) => t.id.equals(id))).write(
        EvaluationsCompanion(
          isDeleted: const Value(true),
          isDirty: const Value(true),
          updatedAt: Value(deletedAt),
        ),
      );

  Future<void> clear() => delete(evaluations).go();
}
