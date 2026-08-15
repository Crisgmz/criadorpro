import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';

/// Resultado de una prueba de campo — `RF-PRU-02`, catálogo cerrado del SRS.
///
/// El vocabulario es zootécnico por obligación (BRD §8): «favorable» y
/// «desfavorable», nunca términos de riña. `undefined` no es un hueco sino un
/// valor con sentido: la prueba se anotó y el resultado se decide después.
enum EvaluationResult {
  favorable('favorable'),
  unfavorable('unfavorable'),
  undefined('undefined');

  const EvaluationResult(this.id);

  final String id;

  static EvaluationResult fromId(String? id) =>
      values.firstWhere((r) => r.id == id, orElse: () => EvaluationResult.undefined);
}

/// Prueba de campo de un ejemplar.
class Evaluation {
  const Evaluation({
    required this.id,
    required this.ownerId,
    required this.birdId,
    required this.date,
    required this.result,
    required this.createdAt,
    required this.updatedAt,
    this.place,
    this.condition,
    this.weightG,
    this.notes,
    this.isDeleted = false,
  });

  factory Evaluation.fromRow(EvaluationRow row) => Evaluation(
    id: row.id,
    ownerId: row.ownerId,
    birdId: row.birdId,
    date: row.date,
    place: row.place,
    result: EvaluationResult.fromId(row.result),
    condition: row.condition,
    weightG: row.weightG,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory Evaluation.fromRemoteJson(Map<String, dynamic> json) => Evaluation(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    birdId: json['bird_id'] as String,
    date: _parseDate(json['date']) ?? DateTime.now(),
    place: json['place'] as String?,
    result: EvaluationResult.fromId(json['result'] as String?),
    condition: (json['condition'] as num?)?.toInt(),
    weightG: (json['weight_g'] as num?)?.toInt(),
    notes: json['notes'] as String?,
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;
  final String birdId;
  final DateTime date;
  final String? place;
  final EvaluationResult result;

  /// Condición del ejemplar, de 1 a 10.
  final int? condition;

  /// Peso en gramos el día de la prueba — `RF-PRU-01`.
  final int? weightG;

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  EvaluationsCompanion toCompanion({bool dirty = false}) => EvaluationsCompanion(
    id: Value(id),
    ownerId: Value(ownerId),
    birdId: Value(birdId),
    date: Value(date),
    place: Value(place),
    result: Value(result.id),
    condition: Value(condition),
    weightG: Value(weightG),
    notes: Value(notes),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    isDeleted: Value(isDeleted),
    isDirty: Value(dirty),
  );

  Map<String, dynamic> toRemoteJson() => {
    'id': id,
    'owner_id': ownerId,
    'bird_id': birdId,
    'date': _formatDate(date),
    'place': place,
    'result': result.id,
    'condition': condition,
    'weight_g': weightG,
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

/// Resumen del criadero — `RF-PRU-03`.
class EvaluationStats {
  const EvaluationStats({
    required this.total,
    required this.favorable,
    required this.averageCondition,
  });

  static const EvaluationStats empty = EvaluationStats(
    total: 0,
    favorable: 0,
    averageCondition: null,
  );

  final int total;
  final int favorable;

  /// `null` cuando ninguna prueba anotó condición: mostrar «0,0» daría a
  /// entender que los ejemplares están en pésimo estado.
  final double? averageCondition;

  /// Porcentaje favorable sobre el total, redondeado. Las pruebas sin definir
  /// cuentan en el total: ocultarlas inflaría el porcentaje.
  int get favorablePercent => total == 0 ? 0 : ((favorable / total) * 100).round();
}
