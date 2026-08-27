import 'dart:convert';

import '../db/daos/sync_queue_dao.dart';

/// Quién gana entre lo que baja del servidor y lo que aún no ha subido —
/// `RS-09`.
///
/// La regla del SRS es «gana el `updated_at` más reciente; en empate gana el
/// servidor», y el usuario no ve el conflicto. Lo que había era una
/// aproximación más burda —lo local pendiente ganaba siempre, sin mirar la
/// hora— con dos agujeros:
///
/// - Una escritura que agota sus cinco intentos (`RS-11`) se queda en la cola
///   hasta que alguien pulse «Sincronizar ahora». Mientras tanto **ningún**
///   cambio remoto de esa fila llegaba, nunca. Es lo que congelaba el plan de
///   un criadero que ya había pagado.
/// - Y aunque la escritura acabara subiendo, el servidor podía tener algo más
///   nuevo puesto desde otro dispositivo, que se descartaba sin compararlo.
///
/// La marca de agua de la bajada sigue avanzando con la fecha remota de **toda**
/// fila vista, incluidas las que gana lo local. No es un descuido: esa versión
/// local es estrictamente más nueva y, al subir, el `touch_updated_at()` del
/// servidor le pondrá una fecha mayor todavía, así que volverá a bajar sola.
class RemoteMerge {
  RemoteMerge._(this._queue, this._pending);

  /// Lee de la cola la versión local pendiente de cada fila de [table].
  static Future<RemoteMerge> forTable(SyncQueueDao queue, String table) async {
    final entries = await queue.pendingFor(table);
    return RemoteMerge._(queue, {
      for (final entry in entries)
        entry.entityId: _PendingWrite(entry.id, _updatedAt(entry.payload)),
    });
  }

  final SyncQueueDao _queue;
  final Map<String, _PendingWrite> _pending;

  /// `true` si la fila remota debe escribirse en Drift.
  ///
  /// Cuando gana el servidor, la escritura local que quedó vieja **se saca de
  /// la cola**. Dejarla ahí la subiría en la próxima pasada y devolvería el
  /// servidor a la versión anterior: el cambio que acaba de ganar se
  /// desharía solo, horas después y sin nada que lo explicara.
  Future<bool> accepts(String id, DateTime remoteUpdatedAt) async {
    final local = _pending[id];
    if (local == null) return true;

    // Sin fecha utilizable en el payload no hay comparación posible: gana lo
    // local, que es lo que el criador acaba de escribir y todavía no ha
    // viajado. Ante la duda, no se pisa al usuario.
    final localAt = local.updatedAt;
    if (localAt == null || localAt.isAfter(remoteUpdatedAt)) return false;

    await _queue.remove(local.queueId);
    _pending.remove(id);
    return true;
  }

  /// `updated_at` del payload encolado. Las dos partes lo escriben en UTC, y
  /// `isAfter` compara instantes, así que da igual con qué zona llegue el otro.
  static DateTime? _updatedAt(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final raw = decoded['updated_at'];
      return raw is String ? DateTime.tryParse(raw) : null;
    } on FormatException {
      return null;
    }
  }
}

class _PendingWrite {
  const _PendingWrite(this.queueId, this.updatedAt);

  final int queueId;
  final DateTime? updatedAt;
}
