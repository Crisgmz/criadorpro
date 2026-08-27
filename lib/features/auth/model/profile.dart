import 'package:drift/drift.dart' show Value;

import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';

/// Perfil del criadero. Guarda, entre otras cosas, el plan contratado —que
/// determina cuántos ejemplares se pueden registrar— y el contador de placas,
/// que es el eje del registro (`RS-01`).
class Profile {
  const Profile({
    required this.id,
    required this.plan,
    required this.createdAt,
    required this.updatedAt,
    this.nextPlate = 1,
    this.email,
    this.fullName,
    this.farmName,
    this.location,
    this.countryCode,
    this.locale,
    this.phone,
    this.avatarUrl,
    this.planExpiresAt,
    this.isPublic = false,
    this.publicBio,
  });

  factory Profile.fromRow(ProfileRow row) => Profile(
    isPublic: row.isPublic,
    publicBio: row.publicBio,
    id: row.id,
    plan: SubscriptionPlan.fromId(row.plan),
    nextPlate: row.nextPlate,
    email: row.email,
    fullName: row.fullName,
    farmName: row.farmName,
    location: row.location,
    countryCode: row.countryCode,
    locale: row.locale,
    phone: row.phone,
    avatarUrl: row.avatarUrl,
    planExpiresAt: row.planExpiresAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  factory Profile.fromRemoteJson(Map<String, dynamic> json) => Profile(
    isPublic: json['is_public'] as bool? ?? false,
    publicBio: json['public_bio'] as String?,
    id: json['id'] as String,
    plan: SubscriptionPlan.fromId(json['plan'] as String?),
    nextPlate: (json['next_plate'] as num?)?.toInt() ?? 1,
    email: json['email'] as String?,
    fullName: json['full_name'] as String?,
    farmName: json['farm_name'] as String?,
    location: json['location'] as String?,
    countryCode: json['country_code'] as String?,
    locale: json['locale'] as String?,
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    planExpiresAt: _parseDate(json['plan_expires_at']),
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
  );

  final String id;
  final SubscriptionPlan plan;

  /// Próxima placa a asignar — `RS-01`.
  final int nextPlate;

  final String? email;
  final String? fullName;
  final String? farmName;
  final String? location;
  final String? countryCode;
  final String? locale;
  final String? phone;
  final String? avatarUrl;
  final DateTime? planExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// El onboarding queda pendiente mientras no haya nombre de criadero
  /// (`RF-ONB-01`). Es lo que mira la guardia del router.
  bool get isOnboardingComplete => (farmName ?? '').trim().isNotEmpty;

  /// Copia con los campos indicados sustituidos.
  ///
  /// Pasar `null` conserva el valor actual en lugar de borrarlo: ningún campo
  /// del perfil se vacía desde la app —se sustituye o se deja como estaba—, así
  /// que distinguir «no lo toques» de «ponlo a nulo» no aportaría nada.
  /// Aparece en el directorio de Comunidad — `RF-COM`. Opt-in.
  final bool isPublic;

  /// Presentación del criadero en el directorio.
  final String? publicBio;

  Profile copyWith({
    String? fullName,
    String? farmName,
    String? location,
    String? countryCode,
    String? locale,
    String? phone,
    String? avatarUrl,
    int? nextPlate,
    SubscriptionPlan? plan,
    DateTime? planExpiresAt,
    bool? isPublic,
    String? publicBio,
    DateTime? updatedAt,
  }) => Profile(
    id: id,
    plan: plan ?? this.plan,
    nextPlate: nextPlate ?? this.nextPlate,
    email: email,
    fullName: fullName ?? this.fullName,
    farmName: farmName ?? this.farmName,
    location: location ?? this.location,
    countryCode: countryCode ?? this.countryCode,
    locale: locale ?? this.locale,
    phone: phone ?? this.phone,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    planExpiresAt: planExpiresAt ?? this.planExpiresAt,
    isPublic: isPublic ?? this.isPublic,
    publicBio: publicBio ?? this.publicBio,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Plan que vale ahora mismo — `RS-12`.
  ///
  /// Un plan de pago caducado vuelve a Free, pero **no en el instante de
  /// vencer**: se conserva [AppConfig.planGracePeriod]. Una suscripción que se
  /// renueva sola vence antes de que llegue el recibo nuevo —la tienda cobra y
  /// confirma con horas de retraso—, y sin margen un criadero de Élite que pagó
  /// pierde la empleomanía a media mañana y la recupera por la tarde.
  ///
  /// Nada se borra al degradar (`RS-03`): lo que se bloquea es crear.
  SubscriptionPlan effectivePlanAt(DateTime now) {
    final expiry = planExpiresAt;
    if (plan == SubscriptionPlan.free || expiry == null) return plan;
    return now.isBefore(expiry.add(AppConfig.planGracePeriod)) ? plan : SubscriptionPlan.free;
  }

  SubscriptionPlan get effectivePlan => effectivePlanAt(DateTime.now());

  ProfilesCompanion toCompanion() => ProfilesCompanion(
    isPublic: Value(isPublic),
    publicBio: Value(publicBio),
    id: Value(id),
    email: Value(email),
    fullName: Value(fullName),
    farmName: Value(farmName),
    location: Value(location),
    countryCode: Value(countryCode),
    locale: Value(locale),
    nextPlate: Value(nextPlate),
    phone: Value(phone),
    avatarUrl: Value(avatarUrl),
    plan: Value(plan.id),
    planExpiresAt: Value(planExpiresAt),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );

  /// Campos que el cliente puede escribir en el servidor.
  ///
  /// `plan`, `plan_expires_at` y `next_plate` quedan fuera a propósito: el plan
  /// solo lo escribe la validación del recibo (`RS-12`) y el contador de placas
  /// solo la RPC `next_plate()` (`RS-01`). Enviarlos sería, además de inútil,
  /// una invitación a creer que el cliente manda sobre ellos.
  Map<String, dynamic> toRemoteJson() => {
    'is_public': isPublic,
    'public_bio': publicBio,
    'id': id,
    'email': email,
    'full_name': fullName,
    'farm_name': farmName,
    'location': location,
    'country_code': countryCode,
    'locale': locale,
    'phone': phone,
    'avatar_url': avatarUrl,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
