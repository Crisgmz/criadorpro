import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/clutches.dart';

part 'clutches_dao.g.dart';

@DriftAccessor(tables: [Clutches])
class ClutchesDao extends DatabaseAccessor<AppDatabase> with _$ClutchesDaoMixin {
  ClutchesDao(super.db);

  Stream<List<ClutchRow>> watchAll(String ownerId) =>
      (select(clutches)
            ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .watch();

  Future<ClutchRow?> findById(String id) =>
      (select(clutches)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Camadas registradas. Es el cuarto contador de Inicio — `RF-REG-01`.
  Stream<int> watchCountForOwner(String ownerId) {
    final total = clutches.id.count();
    final query = selectOnly(clutches)
      ..addColumns([total])
      ..where(clutches.ownerId.equals(ownerId) & clutches.isDeleted.equals(false));
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  Future<void> upsert(ClutchesCompanion clutch) => into(clutches).insertOnConflictUpdate(clutch);

  Future<void> upsertAll(List<ClutchesCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(clutches, rows);
  });

  /// Borrado lógico: la fila se conserva para que la sincronización propague
  /// la baja al resto de dispositivos (`RS-10`).
  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(clutches)..where((t) => t.id.equals(id))).write(
        ClutchesCompanion(
          isDeleted: const Value(true),
          isDirty: const Value(true),
          updatedAt: Value(deletedAt),
        ),
      );

  /// Borra los datos locales al cerrar sesión.
  Future<void> clear() => delete(clutches).go();
}
