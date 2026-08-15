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

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
