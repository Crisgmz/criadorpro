/// Modelos de Comunidad — `RF-COM`.
///
/// Terminología: **solicitud de encuentro** entre dos criaderos. Ningún
/// vocabulario de riña o apuesta llega aquí ni a los `.arb` (BRD §8).
///
/// No hay tablas de Drift para este módulo, a propósito. `RNF-08` permite que
/// Comunidad exija conexión, y es el único sitio donde conviene: un directorio
/// de criaderos ajenos no es el libro del criador. Guardarlo en local mostraría
/// desconocidos que ya se dieron de baja, y una solicitud escrita sin señal que
/// nunca llegó a salir es peor que no poder escribirla.
library;

/// Criadero que decidió aparecer en el directorio.
///
/// Solo trae lo que la vista `public_profiles` expone. El correo, el teléfono
/// y el plan **no** están aquí porque no están allí.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.farmName,
    this.location,
    this.countryCode,
    this.avatarUrl,
    this.bio,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as String,
    farmName: json['farm_name'] as String? ?? '',
    location: json['location'] as String?,
    countryCode: json['country_code'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    bio: json['public_bio'] as String?,
  );

  final String id;
  final String farmName;
  final String? location;
  final String? countryCode;
  final String? avatarUrl;
  final String? bio;
}

/// En qué punto está una solicitud.
enum MeetingStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),

  /// La retiró quien la mandó.
  cancelled('cancelled');

  const MeetingStatus(this.id);

  final String id;

  bool get isOpen => this == MeetingStatus.pending;

  static MeetingStatus fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => MeetingStatus.pending);
}

/// Solicitud de encuentro — `RF-COM`.
///
/// Es el único registro del producto que pertenece a **dos** criaderos, y por
/// eso no lleva `owner_id`: lleva quién la mandó y quién la recibe.
class MeetingRequest {
  const MeetingRequest({
    required this.id,
    required this.fromOwner,
    required this.toOwner,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fromBirdId,
    this.message,
    this.place,
    this.proposedDate,
    this.counterpartName,
  });

  factory MeetingRequest.fromJson(Map<String, dynamic> json) => MeetingRequest(
    id: json['id'] as String,
    fromOwner: json['from_owner'] as String,
    toOwner: json['to_owner'] as String,
    fromBirdId: json['from_bird_id'] as String?,
    message: json['message'] as String?,
    place: json['place'] as String?,
    proposedDate: _parseDate(json['proposed_date']),
    status: MeetingStatus.fromId(json['status'] as String?),
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
  );

  final String id;
  final String fromOwner;
  final String toOwner;
  final String? fromBirdId;
  final String? message;
  final String? place;
  final DateTime? proposedDate;
  final MeetingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Nombre del otro criadero, resuelto aparte para pintar la bandeja.
  ///
  /// No viaja en la fila: el nombre puede cambiar, y congelarlo en la solicitud
  /// dejaría la bandeja mostrando criaderos que ya se llaman de otra forma.
  final String? counterpartName;

  bool isIncomingFor(String ownerId) => toOwner == ownerId;

  /// El otro criadero, visto desde [ownerId].
  String counterpartOf(String ownerId) => isIncomingFor(ownerId) ? fromOwner : toOwner;

  MeetingRequest withCounterpart(String? name) => MeetingRequest(
    id: id,
    fromOwner: fromOwner,
    toOwner: toOwner,
    fromBirdId: fromBirdId,
    message: message,
    place: place,
    proposedDate: proposedDate,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    counterpartName: name,
  );

  Map<String, dynamic> toInsertJson() => {
    'id': id,
    'from_owner': fromOwner,
    'to_owner': toOwner,
    'from_bird_id': fromBirdId,
    'message': message,
    'place': place,
    'proposed_date': proposedDate == null ? null : _formatDate(proposedDate!),
    'status': status.id,
  };

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
