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

/// Qué se registró — pantalla 21.
///
/// El diseño distingue tres cosas que antes cabían todas en «prueba». Importa
/// para las cifras: mezclar un pesaje de rutina con una evaluación de
/// rendimiento hace que el porcentaje favorable deje de significar nada.
enum EvaluationType {
  fieldTest('field_test'),
  physicalCheck('physical_check'),
  conditioning('conditioning');

  const EvaluationType(this.id);

  final String id;

  /// Solo la prueba de campo cuenta para el porcentaje favorable: las otras dos
  /// no tienen un resultado que valorar.
  bool get countsForStats => this == EvaluationType.fieldTest;

  static EvaluationType fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => EvaluationType.fieldTest);
}

/// Condición física final — pantalla 21.
enum FinalCondition {
  optimal('optimal'),
  good('good'),
  needsRest('needs_rest');

  const FinalCondition(this.id);

  final String id;

  static FinalCondition? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// Prueba de campo de un ejemplar.
class Evaluation {
  const Evaluation({
    required this.id,
    required this.ownerId,
    required this.birdId,
    required this.date,
    required this.result,
    this.type = EvaluationType.fieldTest,
    this.durationMin,
    this.stamina,
    this.agility,
    this.response,
    this.finalCondition,
    required this.createdAt,
    required this.updatedAt,
    this.place,
    this.condition,
    this.weightG,
    this.notes,
    this.isDeleted = false,
  });

  factory Evaluation.fromRow(EvaluationRow row) => Evaluation(
    type: EvaluationType.fromId(row.type),
    durationMin: row.durationMin,
    stamina: row.stamina,
    agility: row.agility,
    response: row.response,
    finalCondition: FinalCondition.fromId(row.finalCondition),
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
    type: EvaluationType.fromId(json['type'] as String?),
    durationMin: (json['duration_min'] as num?)?.toInt(),
    stamina: (json['stamina'] as num?)?.toInt(),
    agility: (json['agility'] as num?)?.toInt(),
    response: (json['response'] as num?)?.toInt(),
    finalCondition: FinalCondition.fromId(json['final_condition'] as String?),
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
  final EvaluationType type;

  /// Duración en minutos.
  final int? durationMin;

  /// Índices de desempeño, 1–5. Sustituyen en la interfaz a [condition], que se
  /// conserva para no perder lo ya registrado.
  final int? stamina;
  final int? agility;
  final int? response;

  final FinalCondition? finalCondition;

  /// El «índice» que muestra la ficha: promedio de los índices anotados.
  ///
  /// Ignora los que no se anotaron en vez de contarlos como cero — un cero
  /// hundiría la media de una evaluación en la que solo se midió resistencia.
  double? get performanceIndex {
    final values = [stamina, agility, response].nonNulls.toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Condición del ejemplar, de 1 a 10.
  final int? condition;

  /// Peso en gramos el día de la prueba — `RF-PRU-01`.
  final int? weightG;

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  EvaluationsCompanion toCompanion({bool dirty = false}) => EvaluationsCompanion(
    type: Value(type.id),
    durationMin: Value(durationMin),
    stamina: Value(stamina),
    agility: Value(agility),
    response: Value(response),
    finalCondition: Value(finalCondition?.id),
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
    'type': type.id,
    'duration_min': durationMin,
    'stamina': stamina,
    'agility': agility,
    'response': response,
    'final_condition': finalCondition?.id,
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
    required this.rated,
    required this.favorable,
    required this.averageIndex,
  });

  static const EvaluationStats empty = EvaluationStats(
    total: 0,
    rated: 0,
    favorable: 0,
    averageIndex: null,
  );

  /// Todos los registros anotados, del tipo que sean.
  final int total;

  /// Solo los que tienen un resultado que valorar — las pruebas de campo.
  ///
  /// Es el denominador del porcentaje: una revisión física no es favorable ni
  /// desfavorable, y meterla en el cálculo castiga al criadero que más pesa.
  final int rated;

  final int favorable;

  /// `null` cuando ninguna anotó índices: mostrar «0,0» daría a
  /// entender que los ejemplares están en pésimo estado.
  final double? averageIndex;

  /// Porcentaje favorable sobre las pruebas valorables, redondeado. Las que
  /// quedaron sin definir **sí** cuentan: ocultarlas inflaría el porcentaje.
  int get favorablePercent => rated == 0 ? 0 : ((favorable / rated) * 100).round();
}
