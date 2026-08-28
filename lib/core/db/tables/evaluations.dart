import 'package:drift/drift.dart';

/// Prueba de campo — `RF-PRU-01`.
///
/// El vocabulario es zootécnico y no negociable (BRD §8): esto es una
/// **evaluación de rendimiento**, con resultado favorable o desfavorable. Ni la
/// tabla ni sus valores admiten términos de riña o apuesta.
@DataClassName('EvaluationRow')
class Evaluations extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  /// Ejemplar evaluado. Obligatorio: una prueba sin sujeto no dice nada.
  TextColumn get birdId => text()();

  DateTimeColumn get date => dateTime()();

  /// Lugar de la prueba. Opcional.
  TextColumn get place => text().nullable()();

  /// `favorable` · `unfavorable` · `undefined` — `RF-PRU-02`.
  ///
  /// Se puede guardar sin definir: muchas evaluaciones se anotan sobre la
  /// marcha y el resultado se decide después.
  TextColumn get result => text().withDefault(const Constant('undefined'))();

  /// Condición del ejemplar, de 1 a 10.
  IntColumn get condition => integer().nullable()();

  /// Peso en gramos el día de la prueba — `RF-PRU-01`.
  IntColumn get weightG => integer().nullable()();

  TextColumn get notes => text().nullable()();

  /// Tipo de registro — pantalla 21: `field_test` · `physical_check` ·
  /// `conditioning`.
  ///
  /// El diseño distingue tres cosas que antes cabían todas en «prueba»: la
  /// prueba de campo, la revisión física y la sesión de acondicionamiento. Sin
  /// el tipo, las estadísticas mezclan un pesaje de rutina con una evaluación
  /// de rendimiento y el porcentaje favorable deja de significar nada.
  TextColumn get type => text().withDefault(const Constant('field_test'))();

  /// Duración en minutos.
  IntColumn get durationMin => integer().nullable()();

  /// Índices de desempeño, escala 1–5 «según observación del evaluador».
  ///
  /// Sustituyen en la interfaz a `condition` (1–10 del SRS), que se conserva
  /// para no perder lo ya registrado. El «índice» que muestra la ficha es el
  /// promedio de los tres.
  IntColumn get stamina => integer().nullable()();
  IntColumn get agility => integer().nullable()();
  IntColumn get response => integer().nullable()();

  /// Condición física final: `optimal` · `good` · `needs_rest`.
  TextColumn get finalCondition => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
