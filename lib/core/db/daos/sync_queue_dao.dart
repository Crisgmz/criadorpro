import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_queue_entries.dart';

part 'sync_queue_dao.g.dart';

/// Operaciones que se pueden encolar hacia el backend.
enum SyncOperation { upsert, delete }

@DriftAccessor(tables: [SyncQueueEntries])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Encola un cambio. Si ya había uno pendiente para el mismo registro se
  /// reemplaza: solo importa el último estado, no el historial.
  Future<void> enqueue({
    required String entityTable,
    required String entityId,
    required SyncOperation operation,
    required String payload,
    required DateTime now,
  }) {
    return into(syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        entityTable: entityTable,
        entityId: entityId,
        operation: operation.name,
        payload: payload,
        createdAt: now,
      ),
      onConflict: DoUpdate(
        (_) => SyncQueueEntriesCompanion(
          operation: Value(operation.name),
          payload: Value(payload),
          createdAt: Value(now),
          attempts: const Value(0),
          lastError: const Value(null),
        ),
        target: [syncQueueEntries.entityTable, syncQueueEntries.entityId],
      ),
    );
  }

  /// Pendientes que todavía merecen un reintento automático, más antiguos primero.
  Future<List<SyncTask>> pending({required int maxAttempts}) {
    final query = select(syncQueueEntries)
      ..where((t) => t.attempts.isSmallerThanValue(maxAttempts))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.get();
  }

  Stream<int> watchPendingCount() {
    final total = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)..addColumns([total]);
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Ids con cambios locales aún sin subir. La bajada los salta para no pisar
  /// una edición del usuario con una versión remota más antigua.
  Future<Set<String>> pendingIdsFor(String entityTable) async {
    final rows = await (select(
      syncQueueEntries,
    )..where((t) => t.entityTable.equals(entityTable))).get();
    return rows.map((row) => row.entityId).toSet();
  }

  Future<void> remove(int id) => (delete(syncQueueEntries)..where((t) => t.id.equals(id))).go();

  /// Suma un intento y guarda el motivo. Va en SQL crudo porque un `Companion`
  /// solo admite valores, no expresiones como `attempts = attempts + 1`.
  Future<void> markFailed(int id, String error) => customUpdate(
    'UPDATE sync_queue_entries SET attempts = attempts + 1, last_error = ? WHERE id = ?',
    variables: [Variable<String>(error), Variable<int>(id)],
    updates: {syncQueueEntries},
  );

  /// Devuelve a la cola las entradas que agotaron reintentos (sincronización manual).
  Future<void> resetAttempts() =>
      update(syncQueueEntries).write(const SyncQueueEntriesCompanion(attempts: Value(0)));

  Future<void> clear() => delete(syncQueueEntries).go();
}
