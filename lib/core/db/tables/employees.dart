import 'package:drift/drift.dart';

/// Empleado del criadero — `RF-NOM-01`.
@DataClassName('EmployeeRow')
class Employees extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  /// Puesto, en texto libre: cada criadero nombra los suyos.
  TextColumn get role => text().nullable()();

  TextColumn get phone => text().nullable()();

  /// Cédula. `RV-17` la valida como **advertencia**, nunca como bloqueo: hay
  /// trabajadores sin documento dominicano y el pago tiene que poder
  /// registrarse igual.
  TextColumn get document => text().nullable()();

  /// Salario del período **en centavos**, por el mismo motivo que en
  /// `transactions`: el dinero en coma flotante acumula error.
  IntColumn get salaryCents => integer()();

  /// `weekly` · `biweekly` · `monthly`. Es la periodicidad del salario, no la
  /// del pago: un pago puede cubrir un período distinto si hubo un atraso.
  TextColumn get frequency => text()();

  /// Un empleado que se va no se borra: sus pagos siguen contando en el mes en
  /// que se hicieron. Deja de sumar al costo mensual y de aparecer al pagar.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Foto del empleado — pantalla 30. Opcional: «para identificar al personal
  /// más rápido». Misma pareja que en `birds`: la ruta es local y no viaja, la
  /// URL sí.
  TextColumn get photoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();

  /// Fecha de entrada al criadero.
  DateTimeColumn get startDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
