import 'package:drift/drift.dart';

/// Camada: agrupa a los ejemplares nacidos de un mismo cruce.
///
/// No lleva código propio — el criador identifica la camada por sus
/// progenitores y su fecha, que es como la anota en el libro.
@DataClassName('ClutchRow')
class Clutches extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  TextColumn get fatherId => text().nullable()();
  TextColumn get motherId => text().nullable()();

  /// Fecha de nacimiento de las crías.
  DateTimeColumn get date => dateTime()();

  /// Huevos puestos. Opcional: muchos criadores solo anotan los que nacieron.
  IntColumn get eggs => integer().nullable()();

  /// Crías nacidas, de 1 a 30 (`RV-11`). Determina cuántas placas se reservan.
  IntColumn get hatched => integer()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
