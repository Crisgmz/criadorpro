import 'package:drift/drift.dart';

/// Movimiento contable — `RF-CON-01`.
@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  /// `income` o `expense`.
  TextColumn get type => text()();

  /// Catálogo cerrado (`RF-CON-02`): el usuario no crea categorías propias.
  TextColumn get category => text()();

  /// Importe **en centavos**.
  ///
  /// Dinero en coma flotante es un error clásico: `0.1 + 0.2` no da `0.3`, y en
  /// un balance de dos mil movimientos ese error se acumula hasta ser visible.
  /// En Postgres la columna es `numeric(12,2)`; la conversión entre ambos es
  /// exacta porque solo hay que multiplicar y dividir por cien.
  IntColumn get amountCents => integer()();

  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();

  /// Ejemplar relacionado. Opcional: la venta de un ejemplar concreto se ata a
  /// su ficha, pero un saco de alimento no es de nadie en particular.
  TextColumn get birdId => text().nullable()();

  /// `none` · `weekly` · `biweekly` · `monthly` — `RF-CON-03`.
  TextColumn get recurrence => text().withDefault(const Constant('none'))();

  /// Movimiento del que este se generó automáticamente (`RS-08`).
  ///
  /// Es lo que impide duplicar: al generar los períodos vencidos se comprueba
  /// qué fechas ya existen para esta plantilla.
  TextColumn get recurrenceSourceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
