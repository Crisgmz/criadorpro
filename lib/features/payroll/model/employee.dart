import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';

/// Periodicidad del salario — `RF-NOM-01`.
enum PayFrequency {
  weekly('weekly'),
  biweekly('biweekly'),
  monthly('monthly');

  const PayFrequency(this.id);

  final String id;

  /// Cuántos períodos caben en un mes, para el costo estimado de `RS-07`.
  ///
  /// El 4,33 del semanal es 52 semanas entre 12 meses. No es exacto para
  /// ningún mes concreto —por eso la cifra se rotula como estimación— pero es
  /// la única forma de comparar en la misma escala a quien cobra por semana con
  /// quien cobra por mes.
  double get periodsPerMonth => switch (this) {
    PayFrequency.weekly => 52 / 12,
    PayFrequency.biweekly => 2,
    PayFrequency.monthly => 1,
  };

  /// Días que cubre un período, para proponer el rango al registrar un pago.
  /// El mensual se resuelve por calendario, no por días.
  int? get days => switch (this) {
    PayFrequency.weekly => 7,
    PayFrequency.biweekly => 15,
    PayFrequency.monthly => null,
  };

  static PayFrequency fromId(String? id) =>
      values.firstWhere((f) => f.id == id, orElse: () => PayFrequency.monthly);
}

/// Empleado del criadero.
class Employee {
  const Employee({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.salaryCents,
    required this.frequency,
    required this.createdAt,
    required this.updatedAt,
    this.role,
    this.phone,
    this.document,
    this.isActive = true,
    this.photoPath,
    this.photoUrl,
    this.startDate,
    this.isDeleted = false,
  });

  factory Employee.fromRow(EmployeeRow row) => Employee(
    photoPath: row.photoPath,
    photoUrl: row.photoUrl,
    startDate: row.startDate,
    id: row.id,
    ownerId: row.ownerId,
    name: row.name,
    role: row.role,
    phone: row.phone,
    document: row.document,
    salaryCents: row.salaryCents,
    frequency: PayFrequency.fromId(row.frequency),
    isActive: row.isActive,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDeleted: row.isDeleted,
  );

  factory Employee.fromRemoteJson(Map<String, dynamic> json) => Employee(
    photoUrl: json['photo_url'] as String?,
    startDate: Money.parseDate(json['start_date']),
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String?,
    phone: json['phone'] as String?,
    document: json['document'] as String?,
    salaryCents: Money.centsOf(json['salary']),
    frequency: PayFrequency.fromId(json['frequency'] as String?),
    isActive: json['is_active'] as bool? ?? true,
    createdAt: Money.parseDate(json['created_at']) ?? DateTime.now(),
    updatedAt: Money.parseDate(json['updated_at']) ?? DateTime.now(),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  final String id;
  final String ownerId;
  final String name;
  final String? role;
  final String? phone;
  final String? document;
  final int salaryCents;
  final PayFrequency frequency;
  final bool isActive;

  /// Foto del empleado — pantalla 30: «para identificar al personal más
  /// rápido». Misma pareja que en `birds`: la ruta es local y no viaja, la URL
  /// sí.
  final String? photoPath;
  final String? photoUrl;

  /// Fecha de entrada al criadero.
  final DateTime? startDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  double get salary => salaryCents / 100;

  /// Aporte de este empleado al costo mensual estimado — `RS-07`.
  int get monthlyCostCents => (salaryCents * frequency.periodsPerMonth).round();

  EmployeesCompanion toCompanion({bool dirty = false}) => EmployeesCompanion(
    photoPath: Value(photoPath),
    photoUrl: Value(photoUrl),
    startDate: Value(startDate),
    id: Value(id),
    ownerId: Value(ownerId),
    name: Value(name),
    role: Value(role),
    phone: Value(phone),
    document: Value(document),
    salaryCents: Value(salaryCents),
    frequency: Value(frequency.id),
    isActive: Value(isActive),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    isDeleted: Value(isDeleted),
    isDirty: Value(dirty),
  );

  Map<String, dynamic> toRemoteJson() => {
    // `photo_path` queda fuera: una ruta de este teléfono no significa nada en
    // otro. Lo que viaja es la URL, como en `birds`.
    'photo_url': photoUrl,
    'start_date': startDate == null ? null : Money.formatDate(startDate!),
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'role': role,
    'phone': phone,
    'document': document,
    'salary': salary,
    'frequency': frequency.id,
    'is_active': isActive,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
  };
}

/// Conversiones de dinero y fecha compartidas por el módulo.
///
/// Repiten la regla de `transactions`: el importe viaja como `numeric(12,2)` y
/// se guarda en centavos enteros. `12.45 * 100` da `1244.9999…` en coma
/// flotante, así que truncar perdería un céntimo por registro.
abstract final class Money {
  static int centsOf(Object? amount) {
    final value = (amount as num?)?.toDouble() ?? 0;
    return (value * 100).round();
  }

  static DateTime? parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
