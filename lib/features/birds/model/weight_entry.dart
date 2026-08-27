import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';

/// Una pesada — `RF-REG-14`.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.ownerId,
    required this.birdId,
    required this.weightG,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.evaluationId,
    this.notes,
    this.isDeleted = false,
  });

  factory WeightEntry.fromRow(WeightEntryRow row) => WeightEntry(
    id: row.id,
    ownerId: row.ownerId,
    birdId: row.birdId,
    weightG: row.weightG,
    date: row.date,
    evaluationId: row.evaluationId,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory WeightEntry.fromRemoteJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    birdId: json['bird_id'] as String,
    weightG: (json['weight_g'] as num?)?.toInt() ?? 0,
    date: _parseDate(json['date']) ?? DateTime.now(),
    evaluationId: json['evaluation_id'] as String?,
    notes: json['notes'] as String?,
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;
  final String birdId;
  final int weightG;
  final DateTime date;

  /// Prueba de campo de la que salió — `RF-PRU-07`. `null` si la anotó el
  /// criador a mano.
  final String? evaluationId;

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// `true` cuando la pesada la generó una prueba y no una anotación directa.
  /// La vista lo señala para que el criador sepa de dónde salió el número.
  bool get isFromEvaluation => evaluationId != null;

  double get kilograms => weightG / 1000;

  WeightEntriesCompanion toCompanion({bool dirty = false}) => WeightEntriesCompanion(
    id: Value(id),
    ownerId: Value(ownerId),
    birdId: Value(birdId),
    weightG: Value(weightG),
    date: Value(date),
    evaluationId: Value(evaluationId),
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
    'weight_g': weightG,
    'date': _formatDate(date),
    'evaluation_id': evaluationId,
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

/// Cómo ha ido cambiando el peso, para la ficha.
///
/// Lo que el criador quiere saber no es cuánto pesa hoy —eso ya lo ve— sino si
/// va subiendo o bajando desde la última vez.
class WeightTrend {
  const WeightTrend({required this.entries});

  final List<WeightEntry> entries;

  bool get isEmpty => entries.isEmpty;

  /// La más reciente. Las entradas llegan ordenadas de nueva a vieja.
  WeightEntry? get latest => entries.isEmpty ? null : entries.first;

  WeightEntry? get previous => entries.length < 2 ? null : entries[1];

  /// Diferencia en gramos contra la pesada anterior. `null` con una sola: sin
  /// dos puntos no hay tendencia, y pintar «+0 g» sugeriría que se estancó.
  int? get changeG {
    final last = latest;
    final before = previous;
    if (last == null || before == null) return null;
    return last.weightG - before.weightG;
  }

  bool get isGaining => (changeG ?? 0) > 0;
  bool get isLosing => (changeG ?? 0) < 0;
}
