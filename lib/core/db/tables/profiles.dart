import 'package:drift/drift.dart';

/// Perfil del criadero. `id` es el `auth.users.id` de Supabase.
///
/// Espejo de `public.profiles` (SRS §3). Las restricciones de verdad viven en
/// Postgres; aquí solo se declaran las que ayudan a detectar un error de
/// programación antes de que salga del dispositivo.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  TextColumn get fullName => text().nullable()();

  /// Nombre del criadero. Nulo hasta que el usuario complete el onboarding
  /// (`RF-ONB-01`) — es la señal de «configuración pendiente».
  TextColumn get farmName => text().nullable()();

  /// Municipio o provincia, tal como lo escribe el criador.
  TextColumn get location => text().nullable()();

  /// ISO 3166-1 alfa-2. Determina el símbolo de moneda y el formato telefónico.
  TextColumn get countryCode => text().withLength(min: 2, max: 2).nullable()();

  /// `es` o `en`.
  TextColumn get locale => text().withLength(min: 2, max: 2).nullable()();

  /// Próxima placa a asignar — `RS-01`. Estrictamente creciente: eliminar un
  /// ejemplar no la decrementa ni libera la placa que ya gastó.
  IntColumn get nextPlate => integer().withDefault(const Constant(1))();

  TextColumn get phone => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  /// Id de [SubscriptionPlan]: `free`, `pro`, `elite`.
  TextColumn get plan => text().withDefault(const Constant('free'))();
  DateTimeColumn get planExpiresAt => dateTime().nullable()();

  /// Aparece en el directorio de Comunidad — `RF-COM`.
  ///
  /// **Opt-in**: nace en falso. Nadie se publica por haberse registrado, y
  /// publicarse es una decisión del criador.
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();

  /// Presentación del criadero en el directorio.
  TextColumn get publicBio => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
