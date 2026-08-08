import 'package:drift/drift.dart';

/// Ejemplar. `sex` y `status` se guardan como texto (el nombre del enum) y el
/// modelo de dominio se encarga de la conversión: así la capa de base de datos
/// no depende de tipos del feature.
@DataClassName('BirdRow')
class Birds extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  /// La placa es el eje del producto y lo único obligatorio al registrar: el
  /// criador anota placas, no nombres, y el número correlativo es lo que le
  /// permite migrar su libro sin retranscribirlo (`RS-01`).
  IntColumn get plate => integer()();

  /// Opcional a propósito — `RF-REG-06`.
  TextColumn get name => text().withLength(min: 1, max: 60).nullable()();

  /// `male` | `female` | `unknown`.
  TextColumn get sex => text()();

  /// `active` | `sold` | `deceased` | `loaned`.
  TextColumn get status => text()();

  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get line => text().nullable()();

  /// Gramos enteros. Que se muestre en kilos o libras lo decide el perfil.
  IntColumn get weightG => integer().nullable()();

  /// Genealogía: referencias a otros ejemplares del mismo criadero.
  TextColumn get fatherId => text().nullable()();
  TextColumn get motherId => text().nullable()();
  TextColumn get clutchId => text().nullable()();

  /// Ruta local de la foto. La URL remota llega con la sincronización.
  TextColumn get photoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Solo local: marca lo que todavía no ha subido. La cola de sincronización
  /// sigue siendo la fuente de verdad de qué está pendiente; esto permite
  /// pintarlo en la lista sin consultarla en cada fila.
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
