import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/birds/weight_log.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/birds_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/db/daos/weights_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../model/weight_entry.dart';

/// Historial de pesos — `RF-REG-14`, y el puente con `RF-PRU-07`.
class WeightsRepository implements RemotePuller, WeightLog {
  WeightsRepository({
    required AppDatabase database,
    required WeightsDao weightsDao,
    required BirdsDao birdsDao,
    required SyncQueueDao syncQueue,
    required SupabaseService supabase,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _database = database,
       _weightsDao = weightsDao,
       _birdsDao = birdsDao,
       _syncQueue = syncQueue,
       _supabase = supabase,
       _uuid = uuid,
       _clock = clock;

  final AppDatabase _database;
  final WeightsDao _weightsDao;
  final BirdsDao _birdsDao;
  final SyncQueueDao _syncQueue;
  final SupabaseService _supabase;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  String get table => 'weight_entries';

  Stream<WeightTrend> watchForBird(String birdId) => _weightsDao
      .watchForBird(birdId)
      .map((rows) => WeightTrend(entries: rows.map(WeightEntry.fromRow).toList()));

  /// Anota una pesada del criador — `RF-REG-14`.
  ///
  /// `RV-12` (100–8.000 g) **advierte pero no bloquea**, así que aquí solo se
  /// rechaza lo que no es un peso: cero o negativo. Quien avisa del rango es la
  /// pantalla, con [Validators.isWeightInRange].
  Future<Result<WeightEntry>> save(WeightEntry draft) async {
    if (draft.weightG <= 0) {
      return const Err(ValidationFailure('weight', debugMessage: 'el peso debe ser mayor que 0'));
    }

    final now = _clock();
    if (draft.date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59))) {
      return const Err(ValidationFailure('date', debugMessage: 'fecha futura'));
    }

    final isNew = draft.id.isEmpty;
    final entry = WeightEntry(
      id: isNew ? _uuid.v4() : draft.id,
      ownerId: draft.ownerId,
      birdId: draft.birdId,
      weightG: draft.weightG,
      date: draft.date,
      evaluationId: draft.evaluationId,
      notes: _trimToNull(draft.notes),
      createdAt: isNew ? now : draft.createdAt,
      updatedAt: now,
    );

    return guard(() async {
      await _database.transaction(() async {
        await _persist(entry, now);
        await _refreshCurrentWeight(entry.birdId);
      });
      return entry;
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  Future<Result<void>> delete(String id) async {
    final existing = await _weightsDao.findById(id);
    if (existing == null) {
      return const Err(NotFoundFailure(debugMessage: 'pesada no encontrada'));
    }

    final now = _clock();
    final deleted = WeightEntry.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    return guard(() async {
      await _database.transaction(() async {
        await _weightsDao.softDelete(id, now);
        await _syncQueue.enqueue(
          entityTable: table,
          entityId: id,
          operation: SyncOperation.delete,
          payload: jsonEncode(deleted),
          now: now,
        );
        await _refreshCurrentWeight(existing.birdId);
      });
    }, (error, _) => DatabaseFailure(debugMessage: error.toString(), cause: error));
  }

  // --- Puente con pruebas de campo (`RF-PRU-07`) ----------------------------

  @override
  Future<void> recordFromEvaluation({
    required String ownerId,
    required String birdId,
    required String evaluationId,
    required int weightG,
    required DateTime date,
    required DateTime now,
  }) async {
    if (weightG <= 0) {
      // La prueba se guardó sin peso, o se lo quitaron al editarla: lo que
      // había deja de tener respaldo.
      await removeFromEvaluation(evaluationId: evaluationId, now: now);
      return;
    }

    // Idempotente por prueba: si ya generó una pesada se corrige esa. Editar
    // tres veces la misma prueba no puede dejar tres pesadas.
    final existing = await _weightsDao.findByEvaluation(evaluationId);

    final entry = WeightEntry(
      id: existing?.id ?? _uuid.v4(),
      ownerId: ownerId,
      birdId: birdId,
      weightG: weightG,
      date: date,
      evaluationId: evaluationId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _persist(entry, now);
    await _refreshCurrentWeight(birdId);
  }

  @override
  Future<void> removeFromEvaluation({required String evaluationId, required DateTime now}) async {
    final existing = await _weightsDao.findByEvaluation(evaluationId);
    if (existing == null) return;

    final deleted = WeightEntry.fromRow(existing).toRemoteJson()
      ..['is_deleted'] = true
      ..['updated_at'] = now.toUtc().toIso8601String();

    await _weightsDao.softDelete(existing.id, now);
    await _syncQueue.enqueue(
      entityTable: table,
      entityId: existing.id,
      operation: SyncOperation.delete,
      payload: jsonEncode(deleted),
      now: now,
    );
    await _refreshCurrentWeight(existing.birdId);
  }

  // --- Interno --------------------------------------------------------------

  /// Deja `birds.weight_g` con la pesada más reciente.
  ///
  /// La columna se mantiene porque la lista y la ficha la leen fila a fila, y
  /// agregar el historial en cada una costaría una consulta por ejemplar. Aquí
  /// es un dato derivado: **nadie más la escribe**.
  ///
  /// No toca `updated_at` del ejemplar: el peso no es una edición del criador
  /// sobre la ficha, y moverlo haría que esta fila ganara la resolución de
  /// conflictos (`RS-09`) contra un cambio real hecho en otro dispositivo.
  Future<void> _refreshCurrentWeight(String birdId) async {
    final latest = await _weightsDao.latestForBird(birdId);
    await _birdsDao.setCurrentWeight(birdId, latest?.weightG);
  }

  Future<void> _persist(WeightEntry entry, DateTime now) async {
    await _weightsDao.upsert(entry.toCompanion(dirty: true));
    await _syncQueue.enqueue(
      entityTable: table,
      entityId: entry.id,
      operation: SyncOperation.upsert,
      payload: jsonEncode(entry.toRemoteJson()),
      now: now,
    );
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
    final incoming = <WeightEntriesCompanion>[];
    final touched = <String>{};
    for (final row in rows) {
      final entry = WeightEntry.fromRemoteJson(row);
      if (latest == null || entry.updatedAt.isAfter(latest)) latest = entry.updatedAt;
      if (pending.contains(entry.id)) continue;
      incoming.add(entry.toCompanion());
      touched.add(entry.birdId);
    }

    if (incoming.isNotEmpty) {
      await _weightsDao.upsertAll(incoming);
      // El peso vigente es derivado: tras bajar pesadas de otro dispositivo hay
      // que recalcularlo, o la ficha seguiría mostrando el anterior.
      for (final birdId in touched) {
        await _refreshCurrentWeight(birdId);
      }
    }
    return latest;
  }
}
