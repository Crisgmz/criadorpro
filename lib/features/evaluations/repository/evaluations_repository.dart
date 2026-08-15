import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/evaluations_dao.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../model/evaluation.dart';

/// Pruebas de campo — `RF-PRU`.
class EvaluationsRepository implements RemotePuller {
  EvaluationsRepository({
    required AppDatabase database,
    required EvaluationsDao evaluationsDao,
    required ProfilesDao profilesDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _evaluationsDao = evaluationsDao,
       _profilesDao = profilesDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _uuid = uuid,
       _clock = clock;

  final AppDatabase _database;
  final EvaluationsDao _evaluationsDao;
  final ProfilesDao _profilesDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Condición del ejemplar — escala del SRS.
  static const int minCondition = 1;
  static const int maxCondition = 10;

  @override
  String get table => 'evaluations';

  Stream<List<Evaluation>> watchAll({required String ownerId, EvaluationResult? result}) =>
      _evaluationsDao
          .watchAll(ownerId: ownerId, result: result?.id)
          .map((rows) => rows.map(Evaluation.fromRow).toList());

  /// `RF-PRU-05` — solo las pruebas de ese ejemplar.
  Stream<List<Evaluation>> watchForBird(String birdId) =>
      _evaluationsDao.watchForBird(birdId).map((rows) => rows.map(Evaluation.fromRow).toList());

  /// `RF-PRU-03` — total, porcentaje favorable y condición promedio.
  ///
  /// Se calcula en memoria sobre las filas ya cargadas y no con tres consultas
  /// agregadas: el criadero típico tiene cientos de pruebas, no millones, y así
  /// las tres cifras salen siempre del mismo instante de la base.
  Stream<EvaluationStats> watchStats(String ownerId) =>
      _evaluationsDao.watchForStats(ownerId).map((rows) {
        if (rows.isEmpty) return EvaluationStats.empty;

        var favorable = 0;
        var conditionSum = 0;
        var conditionCount = 0;

        for (final row in rows) {
          if (EvaluationResult.fromId(row.result) == EvaluationResult.favorable) favorable++;
          final condition = row.condition;
          if (condition != null) {
            conditionSum += condition;
            conditionCount++;
          }
        }

        return EvaluationStats(
          total: rows.length,
          favorable: favorable,
          // El promedio solo cuenta las pruebas que anotaron condición: incluir
          // las que la dejaron en blanco como cero hundiría la media.
          averageCondition: conditionCount == 0 ? null : conditionSum / conditionCount,
        );
      });

  /// `RF-PRU-06` — el módulo es de Pro en adelante.
  ///
  /// Se comprueba en la capa de datos y no solo en la interfaz: `RS-02` es
  /// explícito en que los límites de plan se evalúan aquí, para que ninguna
  /// otra vía de alta pueda saltárselos.
  Future<bool> isAvailableFor(String ownerId) async {
    final profile = await _profilesDao.findById(ownerId);
    return SubscriptionPlan.fromId(profile?.plan) != SubscriptionPlan.free;
  }

  Future<Result<Evaluation>> save(Evaluation draft) async {
    if (draft.birdId.isEmpty) {
      return const Err(ValidationFailure('birdId', debugMessage: 'ejemplar obligatorio'));
    }

    final condition = draft.condition;
    if (condition != null && (condition < minCondition || condition > maxCondition)) {
      return const Err(ValidationFailure('condition', debugMessage: 'condición fuera de 1..10'));
    }

    // `RV-09`: la prueba no puede ser futura.
    final now = _clock();
    if (draft.date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59))) {
      return const Err(ValidationFailure('date', debugMessage: 'fecha futura'));
    }

    if (!await isAvailableFor(draft.ownerId)) {
      return const Err(
        PlanLimitFailure(limit: 0, current: 0, debugMessage: 'pruebas de campo requieren Pro'),
      );
    }

    final isNew = draft.id.isEmpty;
    final evaluation = Evaluation(
      id: isNew ? _uuid.v4() : draft.id,
      ownerId: draft.ownerId,
      birdId: draft.birdId,
      date: draft.date,
      place: _trimToNull(draft.place),
      result: draft.result,
      condition: draft.condition,
      weightG: draft.weightG,
      notes: _trimToNull(draft.notes),
      createdAt: isNew ? now : draft.createdAt,
      updatedAt: now,
    );

    return guard(() async {
      await _database.transaction(() async {
        await _evaluationsDao.upsert(evaluation.toCompanion(dirty: true));
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: evaluation.id,
          operation: SyncOperation.upsert,
          payload: jsonEncode(evaluation.toRemoteJson()),
          now: now,
        );
      });
      return evaluation;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  Future<Result<void>> delete(String id) async {
    final existing = await _evaluationsDao.findById(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'evaluation no encontrada'));
    }

    final now = _clock();
    final deleted = Evaluation.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    return guard(() async {
      await _database.transaction(() async {
        await _evaluationsDao.softDelete(id, now);
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted),
          now: now,
        );
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<DateTime?> pull({required String ownerId, DateTime? since}) async {
    if (!_supabase.isEnabled) return null;

    final query = _supabase.client.from(table).select().eq('owner_id', ownerId);
    final rows = since == null
        ? await query
        : await query.gt('updated_at', since.toUtc().toIso8601String());

    if (rows.isEmpty) return null;

    final pending = await _syncQueue.pendingIdsFor(table);

    DateTime? latest;
    final incoming = <EvaluationsCompanion>[];
    for (final row in rows) {
      final evaluation = Evaluation.fromRemoteJson(row);
      if (latest == null || evaluation.updatedAt.isAfter(latest)) latest = evaluation.updatedAt;
      if (pending.contains(evaluation.id)) continue;
      incoming.add(evaluation.toCompanion());
    }

    if (incoming.isNotEmpty) await _evaluationsDao.upsertAll(incoming);
    return latest;
  }
}
