import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../config/app_config.dart';
import '../db/daos/sync_queue_dao.dart';
import '../network/connectivity_service.dart';
import '../network/supabase_service.dart';

/// Una tabla que sabe traerse sus cambios remotos.
///
/// La subida es genérica (la cola lleva el JSON listo), pero la bajada necesita
/// saber cómo mapear la fila remota a Drift, así que la implementa cada
/// repositorio.
abstract interface class RemotePuller {
  /// Nombre de la tabla en Supabase.
  String get table;

  /// Trae las filas modificadas después de [since] y las escribe en Drift.
  /// Devuelve el `updated_at` más reciente que vio, para guardarlo como marca.
  Future<DateTime?> pull({required String ownerId, DateTime? since});
}

enum SyncStatus { idle, syncing, done, failed, offline }

/// Drena la cola de escrituras y baja los cambios remotos.
///
/// Orden importante: primero se sube y luego se baja, para que un cambio local
/// pendiente no sea pisado por una versión remota más antigua.
class SyncService {
  SyncService({
    required SyncQueueDao queue,
    required SupabaseService supabase,
    required ConnectivityService connectivity,
    required SharedPreferences preferences,
    required List<RemotePuller> pullers,
  }) : _queue = queue,
       _supabase = supabase,
       _connectivity = connectivity,
       _preferences = preferences,
       _pullers = pullers;

  final SyncQueueDao _queue;
  final SupabaseService _supabase;
  final ConnectivityService _connectivity;
  final SharedPreferences _preferences;
  final List<RemotePuller> _pullers;

  final StreamController<SyncStatus> _status = StreamController<SyncStatus>.broadcast();
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _timer;
  bool _running = false;

  Stream<SyncStatus> get status => _status.stream;

  Stream<int> get pendingCount => _queue.watchPendingCount();

  /// Arranca los disparadores automáticos: al recuperar conexión y cada
  /// [AppConfig.syncInterval].
  /// Tras una migración del esquema local, las marcas de bajada ya no valen: se
  /// refieren a tablas con otra forma. Borrarlas fuerza una descarga completa,
  /// que es lo que repuebla lo que la migración tuvo que recrear.
  Future<void> resetWatermarksIfSchemaChanged(int schemaVersion) async {
    const key = 'sync.schema_version';
    if (_preferences.getInt(key) == schemaVersion) return;
    await clearWatermarks();
    await _preferences.setInt(key, schemaVersion);
  }

  void start() {
    if (!_supabase.isEnabled) return;
    _connectivitySubscription ??= _connectivity.onStatusChange.listen((online) {
      if (online) unawaited(syncNow());
    });

    // Abrir sesión es el otro disparador imprescindible: `RF-SIN-08` exige
    // bajar los datos del propietario nada más entrar. Sin esto, quien se
    // registra o inicia sesión con la app ya abierta esperaría al pulso de
    // cinco minutos para ver su perfil.
    _authSubscription ??= _supabase.authStateChanges.listen((state) {
      if (state.session != null) unawaited(syncNow());
    });

    _timer ??= Timer.periodic(AppConfig.syncInterval, (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  /// Sincroniza ahora. Es idempotente: si ya hay una pasada en curso, no hace nada.
  Future<void> syncNow() async {
    if (_running || !_supabase.isEnabled) return;
    final ownerId = _supabase.currentUserId;
    if (ownerId == null) return;

    if (!await _connectivity.isOnline()) {
      _emit(SyncStatus.offline);
      return;
    }

    _running = true;
    _emit(SyncStatus.syncing);
    try {
      await _push();
      await _pull(ownerId);
      _emit(SyncStatus.done);
    } catch (error, stackTrace) {
      debugPrint('SyncService falló: $error\n$stackTrace');
      _emit(SyncStatus.failed);
    } finally {
      _running = false;
    }
  }

  /// Reintenta también lo que agotó sus intentos automáticos.
  Future<void> retryFailed() async {
    await _queue.resetAttempts();
    await syncNow();
  }

  Future<void> _push() async {
    final tasks = await _queue.pending(maxAttempts: AppConfig.maxSyncAttempts);
    for (final task in tasks) {
      try {
        final payload = jsonDecode(task.payload) as Map<String, dynamic>;
        if (task.operation == SyncOperation.delete.name) {
          await _supabase.client
              .from(task.entityTable)
              .update({'is_deleted': true, 'updated_at': payload['updated_at']})
              .eq('id', task.entityId);
        } else {
          await _supabase.client.from(task.entityTable).upsert(payload);
        }
        await _queue.remove(task.id);
      } catch (error) {
        // Un fallo puntual no debe detener el resto de la cola.
        await _queue.markFailed(task.id, error.toString());
      }
    }
  }

  Future<void> _pull(String ownerId) async {
    for (final puller in _pullers) {
      final since = _lastPulledAt(puller.table);
      final latest = await puller.pull(ownerId: ownerId, since: since);
      if (latest != null) {
        await _preferences.setString(_key(puller.table), latest.toUtc().toIso8601String());
      }
    }
  }

  DateTime? _lastPulledAt(String table) {
    final raw = _preferences.getString(_key(table));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Al cerrar sesión: la próxima cuenta debe bajarse todo desde cero.
  Future<void> clearWatermarks() async {
    for (final puller in _pullers) {
      await _preferences.remove(_key(puller.table));
    }
  }

  static String _key(String table) => 'sync.last_pulled_at.$table';

  void _emit(SyncStatus status) {
    if (!_status.isClosed) _status.add(status);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _connectivitySubscription?.cancel();
    await _authSubscription?.cancel();
    await _status.close();
  }
}
