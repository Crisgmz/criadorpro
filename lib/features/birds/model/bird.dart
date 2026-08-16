import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';
import '../../../core/domain/sex.dart';

/// Situación del ejemplar dentro del criadero — catálogo cerrado del SRS §5.
enum BirdStatus {
  active('active'),
  sold('sold'),
  deceased('deceased'),
  loaned('loaned');

  const BirdStatus(this.id);

  final String id;

  static BirdStatus fromId(String? id) =>
      values.firstWhere((status) => status.id == id, orElse: () => BirdStatus.active);
}

/// Ejemplar. Modelo de dominio: la UI y los ViewModels solo hablan con esta
/// clase, nunca con `BirdRow` ni con el JSON de Supabase.
class Bird {
  const Bird({
    required this.id,
    required this.ownerId,
    required this.plate,
    required this.sex,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.name,
    this.birthDate,
    this.color,
    this.comb,
    this.line,
    this.weightG,
    this.fatherId,
    this.motherId,
    this.clutchId,
    this.photoPath,
    this.photoUrl,
    this.birthMark,
    this.wingBandLeft,
    this.wingBandRight,
    this.notes,
    this.isDeleted = false,
  });

  /// Ejemplar en blanco para el formulario de alta. El `id` definitivo y la
  /// placa los pone el repositorio al guardar.
  factory Bird.draft({required String ownerId, required DateTime now}) => Bird(
    id: '',
    ownerId: ownerId,
    plate: 0,
    sex: Sex.unknown,
    status: BirdStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  factory Bird.fromRow(BirdRow row) => Bird(
    id: row.id,
    ownerId: row.ownerId,
    plate: row.plate,
    name: row.name,
    sex: Sex.fromId(row.sex),
    status: BirdStatus.fromId(row.status),
    birthDate: row.birthDate,
    color: row.color,
    comb: row.comb,
    line: row.line,
    weightG: row.weightG,
    fatherId: row.fatherId,
    motherId: row.motherId,
    clutchId: row.clutchId,
    photoPath: row.photoPath,
    photoUrl: row.photoUrl,
    birthMark: row.birthMark,
    wingBandLeft: row.wingBandLeft,
    wingBandRight: row.wingBandRight,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory Bird.fromRemoteJson(Map<String, dynamic> json) => Bird(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    plate: (json['plate'] as num?)?.toInt() ?? 0,
    name: json['name'] as String?,
    sex: Sex.fromId(json['sex'] as String?),
    status: BirdStatus.fromId(json['status'] as String?),
    birthDate: _parseDate(json['birth_date']),
    color: json['color'] as String?,
    comb: json['comb'] as String?,
    line: json['line'] as String?,
    weightG: (json['weight_g'] as num?)?.toInt(),
    fatherId: json['father_id'] as String?,
    motherId: json['mother_id'] as String?,
    clutchId: json['clutch_id'] as String?,
    photoUrl: json['photo_url'] as String?,
    birthMark: json['birth_mark'] as String?,
    wingBandLeft: json['wing_band_left'] as String?,
    wingBandRight: json['wing_band_right'] as String?,
    notes: json['notes'] as String?,
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;

  /// Número de placa. Lo único obligatorio del ejemplar (`RF-REG-06`).
  final int plate;

  /// Opcional: el criador identifica por placa, no por nombre.
  final String? name;

  final Sex sex;
  final BirdStatus status;
  final DateTime? birthDate;

  /// Color del plumaje y tipo de cresta — catálogos abiertos por criadero.
  final String? color;
  final String? comb;
  final String? line;

  /// Peso en gramos enteros (SRS §4).
  final int? weightG;

  /// Genealogía. Apuntan a otros ejemplares del mismo criadero.
  final String? fatherId;
  final String? motherId;
  final String? clutchId;

  /// Ruta en el dispositivo; no se sube en el JSON.
  final String? photoPath;

  /// URL en Storage, la rellena la sincronización.
  final String? photoUrl;

  /// Marca de nacimiento: posiciones separadas por comas (`1,4`) o `none`.
  final String? birthMark;

  /// Cintas de ala, el identificador que se lee de lejos.
  final String? wingBandLeft;
  final String? wingBandRight;

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  bool get isNew => id.isEmpty;

  /// Lo que se muestra cuando hay que nombrarlo en una lista: el nombre si lo
  /// tiene y, si no, su placa. Nunca queda en blanco.
  String get displayName => (name ?? '').trim().isEmpty ? '#$plate' : name!.trim();

  BirdsCompanion toCompanion({bool dirty = false}) => BirdsCompanion(
    id: Value(id),
    ownerId: Value(ownerId),
    plate: Value(plate),
    name: Value(name),
    sex: Value(sex.id),
    status: Value(status.id),
    birthDate: Value(birthDate),
    color: Value(color),
    comb: Value(comb),
    line: Value(line),
    weightG: Value(weightG),
    fatherId: Value(fatherId),
    motherId: Value(motherId),
    clutchId: Value(clutchId),
    photoPath: Value(photoPath),
    photoUrl: Value(photoUrl),
    birthMark: Value(birthMark),
    wingBandLeft: Value(wingBandLeft),
    wingBandRight: Value(wingBandRight),
    notes: Value(notes),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    isDeleted: Value(isDeleted),
    isDirty: Value(dirty),
  );

  /// Payload que viaja a Supabase. `photo_path` queda fuera: es local.
  Map<String, dynamic> toRemoteJson() => {
    'id': id,
    'owner_id': ownerId,
    'plate': plate,
    'name': name,
    'sex': sex.id,
    'status': status.id,
    'birth_date': birthDate == null ? null : _formatDate(birthDate!),
    'color': color,
    'comb': comb,
    'line': line,
    'weight_g': weightG,
    'father_id': fatherId,
    'mother_id': motherId,
    'clutch_id': clutchId,
    'photo_url': photoUrl,
    'birth_mark': birthMark,
    'wing_band_left': wingBandLeft,
    'wing_band_right': wingBandRight,
    'notes': notes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
  };

  Bird copyWith({
    String? id,
    int? plate,
    Sex? sex,
    BirdStatus? status,
    DateTime? updatedAt,
    bool? isDeleted,
    String? Function()? name,
    DateTime? Function()? birthDate,
    String? Function()? color,
    String? Function()? comb,
    String? Function()? line,
    int? Function()? weightG,
    String? Function()? fatherId,
    String? Function()? motherId,
    String? Function()? clutchId,
    String? Function()? photoPath,
    String? Function()? photoUrl,
    String? Function()? birthMark,
    String? Function()? wingBandLeft,
    String? Function()? wingBandRight,
    String? Function()? notes,
  }) => Bird(
    id: id ?? this.id,
    ownerId: ownerId,
    plate: plate ?? this.plate,
    sex: sex ?? this.sex,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    // Los opcionales se pasan como función para poder distinguir "no tocar"
    // de "poner a null" (p. ej. quitarle el padre a un ejemplar).
    name: name == null ? this.name : name(),
    birthDate: birthDate == null ? this.birthDate : birthDate(),
    color: color == null ? this.color : color(),
    comb: comb == null ? this.comb : comb(),
    line: line == null ? this.line : line(),
    weightG: weightG == null ? this.weightG : weightG(),
    fatherId: fatherId == null ? this.fatherId : fatherId(),
    motherId: motherId == null ? this.motherId : motherId(),
    clutchId: clutchId == null ? this.clutchId : clutchId(),
    photoPath: photoPath == null ? this.photoPath : photoPath(),
    photoUrl: photoUrl == null ? this.photoUrl : photoUrl(),
    birthMark: birthMark == null ? this.birthMark : birthMark(),
    wingBandLeft: wingBandLeft == null ? this.wingBandLeft : wingBandLeft(),
    wingBandRight: wingBandRight == null ? this.wingBandRight : wingBandRight(),
    notes: notes == null ? this.notes : notes(),
    isDeleted: isDeleted ?? this.isDeleted,
  );

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
