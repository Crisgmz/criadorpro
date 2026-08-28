import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';
import 'bird.dart';

/// Estado del cruce — pantalla 11.
///
/// Es del criador, no del ave: dice si ese cruce fue una prueba, si ya está
/// hecho, o si se repitió. Sin él, dos camadas de los mismos reproductores son
/// indistinguibles seis meses después.
enum CrossStatus {
  test('test'),
  done('done'),
  repeated('repeated');

  const CrossStatus(this.id);

  final String id;

  static CrossStatus fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => CrossStatus.done);
}

/// Camada: un cruce con fecha y las crías que salieron de él.
///
/// No tiene código propio porque el criador no se lo pone: la identifica por
/// sus progenitores y la fecha, que es como la anota en el libro.
class Clutch {
  const Clutch({
    required this.id,
    required this.ownerId,
    required this.date,
    required this.hatched,
    required this.createdAt,
    required this.updatedAt,
    this.fatherId,
    this.motherId,
    this.eggs,
    this.notes,
    this.crossStatus = CrossStatus.done,
    this.birthMark,
    this.wingBandLeft,
    this.wingBandRight,
    this.isDeleted = false,
  });

  factory Clutch.fromRow(ClutchRow row) => Clutch(
    crossStatus: CrossStatus.fromId(row.crossStatus),
    birthMark: row.birthMark,
    wingBandLeft: row.wingBandLeft,
    wingBandRight: row.wingBandRight,
    id: row.id,
    ownerId: row.ownerId,
    fatherId: row.fatherId,
    motherId: row.motherId,
    date: row.date,
    eggs: row.eggs,
    hatched: row.hatched,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory Clutch.fromRemoteJson(Map<String, dynamic> json) => Clutch(
    crossStatus: CrossStatus.fromId(json['cross_status'] as String?),
    birthMark: json['birth_mark'] as String?,
    wingBandLeft: json['wing_band_left'] as String?,
    wingBandRight: json['wing_band_right'] as String?,
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    fatherId: json['father_id'] as String?,
    motherId: json['mother_id'] as String?,
    date: _parseDate(json['date']) ?? DateTime.now(),
    eggs: (json['eggs'] as num?)?.toInt(),
    hatched: (json['hatched'] as num?)?.toInt() ?? 1,
    notes: json['notes'] as String?,
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;

  /// Progenitores. Opcionales: se puede anotar una camada sin tener aún
  /// registrados al padre o a la madre.
  final String? fatherId;
  final String? motherId;

  /// Fecha de nacimiento de las crías; la heredan todas.
  final DateTime date;

  /// Huevos puestos. Muchos criadores solo anotan los que nacieron.
  final int? eggs;

  /// Crías nacidas, de 1 a 30 (`RV-11`). Determina cuántas placas se reservan.
  final int hatched;

  /// «Notas de objetivo» en el diseño: qué se buscaba con el cruce.
  final String? notes;

  final CrossStatus crossStatus;

  /// Marca y cintas **de toda la camada**. El diseño las captura una vez al
  /// registrar el cruce, no ave por ave: las crías de una camada se marcan
  /// igual, y repetirlo quince veces es lo que hace que no se marque ninguna.
  final String? birthMark;
  final String? wingBandLeft;
  final String? wingBandRight;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// Huevos que no llegaron a nacer. `null` si no se anotó la puesta.
  int? get unhatched => eggs == null ? null : eggs! - hatched;

  ClutchesCompanion toCompanion({bool dirty = false}) => ClutchesCompanion(
    crossStatus: Value(crossStatus.id),
    birthMark: Value(birthMark),
    wingBandLeft: Value(wingBandLeft),
    wingBandRight: Value(wingBandRight),
    id: Value(id),
    ownerId: Value(ownerId),
    fatherId: Value(fatherId),
    motherId: Value(motherId),
    date: Value(date),
    eggs: Value(eggs),
    hatched: Value(hatched),
    notes: Value(notes),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    isDeleted: Value(isDeleted),
    isDirty: Value(dirty),
  );

  Map<String, dynamic> toRemoteJson() => {
    'cross_status': crossStatus.id,
    'birth_mark': birthMark,
    'wing_band_left': wingBandLeft,
    'wing_band_right': wingBandRight,
    'id': id,
    'owner_id': ownerId,
    'father_id': fatherId,
    'mother_id': motherId,
    'date': _formatDate(date),
    'eggs': eggs,
    'hatched': hatched,
    'notes': notes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
  };

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Lo que devuelve registrar una camada: la camada y sus crías ya con placa.
///
/// Van juntas porque el criador necesita ver de inmediato qué placas se
/// asignaron — es la confirmación de que el bloque quedó reservado (`RF-REG-10`).
class ClutchRegistration {
  const ClutchRegistration({required this.clutch, required this.chicks});

  final Clutch clutch;
  final List<Bird> chicks;

  /// Rango de placas asignado, para el mensaje de confirmación.
  int get firstPlate => chicks.first.plate;
  int get lastPlate => chicks.last.plate;
}
