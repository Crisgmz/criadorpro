import 'package:drift/drift.dart';

/// Cola de escrituras pendientes de subir. Todo cambio local entra aquí en la
/// misma transacción que la escritura en Drift, así nunca se pierde un dato
/// aunque la app se cierre sin conexión.
@DataClassName('SyncTask')
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nombre de la tabla remota, p. ej. `birds`.
  TextColumn get entityTable => text()();
  TextColumn get entityId => text()();

  /// `upsert` | `delete`.
  TextColumn get operation => text()();

  /// Fila serializada en JSON, tal cual se enviará a Supabase.
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    // Una sola entrada pendiente por registro: los reintentos reemplazan el
    // payload en vez de acumular filas.
    {entityTable, entityId},
  ];
}
