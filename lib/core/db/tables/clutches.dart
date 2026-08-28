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

  /// «Notas de objetivo» en el diseño: qué se buscaba con el cruce.
  TextColumn get notes => text().nullable()();

  /// Estado del cruce — pantalla 11: `test` · `done` · `repeated`.
  ///
  /// Es del criador, no del ave: dice si ese cruce fue una prueba, si ya está
  /// hecho, o si se repitió. Sin él, dos camadas de los mismos reproductores
  /// son indistinguibles seis meses después.
  TextColumn get crossStatus => text().withDefault(const Constant('done'))();

  /// Marca de nacimiento y cintas **de toda la camada**.
  ///
  /// El diseño las captura una vez al registrar el cruce, no ave por ave: las
  /// crías de una misma camada se marcan igual, y repetirlo quince veces es lo
  /// que hace que no se marque ninguna. Cada cría nace con estos valores y
  /// puede corregirlos luego en su ficha.
  TextColumn get birthMark => text().nullable()();
  TextColumn get wingBandLeft => text().nullable()();
  TextColumn get wingBandRight => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
