import 'package:drift/drift.dart';

/// Peso de un ejemplar en una fecha — `RF-REG-14`.
///
/// `birds.weight_g` guardaba **un solo** peso, así que anotar el de hoy borraba
/// el de la semana pasada. Para un criadero eso es perder el dato: lo que dice
/// si un ave va bien no es cuánto pesa, sino cómo ha ido cambiando.
///
/// La columna de `birds` se queda: es el peso vigente y lo consultan la lista y
/// la ficha sin tener que agregar esta tabla en cada fila. Quien la mantiene al
/// día es el repositorio, con el registro más reciente.
@DataClassName('WeightEntryRow')
class WeightEntries extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get birdId => text()();

  /// `RV-12` — 100 a 8.000 g. Fuera de rango **advierte pero deja guardar**:
  /// un pollito de 90 g existe, y bloquearlo obligaría al criador a mentir.
  IntColumn get weightG => integer()();

  DateTimeColumn get date => dateTime()();

  /// Prueba de campo de la que salió el peso — `RF-PRU-07`.
  ///
  /// Es lo que evita duplicar: registrar la prueba con peso crea la entrada, y
  /// editar la prueba la actualiza en vez de añadir otra.
  TextColumn get evaluationId => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
