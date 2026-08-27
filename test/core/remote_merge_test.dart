import 'dart:convert';

import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/db/daos/sync_queue_dao.dart';
import 'package:criadorpro/core/sync/remote_merge.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RS-09` — gana el `updated_at` más reciente; en empate, el servidor.
void main() {
  late AppDatabase database;
  late SyncQueueDao queue;

  const table = 'birds';
  const id = 'bird-1';
  final now = DateTime.utc(2026, 8, 27, 12);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queue = database.syncQueueDao;
  });

  tearDown(() => database.close());

  Future<void> enqueue({DateTime? updatedAt, String? rawPayload, int attempts = 0}) async {
    await queue.enqueue(
      entityTable: table,
      entityId: id,
      operation: SyncOperation.upsert,
      payload: rawPayload ?? jsonEncode({'id': id, 'updated_at': updatedAt?.toIso8601String()}),
      now: now,
    );
    for (var i = 0; i < attempts; i++) {
      final pending = await queue.pendingFor(table);
      await queue.markFailed(pending.single.id, 'sin red');
    }
  }

  Future<int> queueLength() async => (await queue.pendingFor(table)).length;

  test('sin nada en cola, la fila remota entra', () async {
    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now), isTrue);
  });

  test('lo local más nuevo gana y se queda en la cola', () async {
    await enqueue(updatedAt: now);

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now.subtract(const Duration(minutes: 5))), isFalse);
    expect(await queueLength(), 1, reason: 'sigue pendiente de subir');
  });

  test('lo remoto más nuevo gana y retira la escritura que quedó vieja', () async {
    await enqueue(updatedAt: now.subtract(const Duration(minutes: 5)));

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now), isTrue);

    // Dejarla en la cola la subiría después y devolvería el servidor a la
    // versión anterior: el cambio que acaba de ganar se desharía solo.
    expect(await queueLength(), 0);
  });

  test('en empate gana el servidor', () async {
    await enqueue(updatedAt: now);

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now), isTrue);
    expect(await queueLength(), 0);
  });

  test('una entrada con los reintentos agotados ya no bloquea la bajada', () async {
    // El caso que congelaba el plan: `_push` no la reintenta sola (`RS-11`) y
    // antes se quedaba ahí impidiendo para siempre que bajara nada de esa fila.
    await enqueue(updatedAt: now.subtract(const Duration(days: 2)), attempts: 5);

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now), isTrue);
    expect(await queueLength(), 0);
  });

  test('sin fecha en el payload gana lo local, que es lo prudente', () async {
    await enqueue(updatedAt: null);

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now), isFalse);
    expect(await queueLength(), 1);
  });

  test('un payload ilegible tampoco se pisa', () async {
    await enqueue(rawPayload: 'esto no es json');

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now), isFalse);
    expect(await queueLength(), 1);
  });

  test('la cola de otra tabla no interfiere', () async {
    await enqueue(updatedAt: now);

    final merge = await RemoteMerge.forTable(queue, 'clutches');
    expect(await merge.accepts(id, now.subtract(const Duration(days: 1))), isTrue);
    expect(await queueLength(), 1, reason: 'la entrada de `birds` sigue intacta');
  });

  test('la comparación es de instantes, no de zona horaria', () async {
    // El payload va en UTC y el modelo remoto llega en hora local: comparar los
    // objetos sin más los haría distintos aunque sean el mismo momento.
    await enqueue(updatedAt: now);

    final merge = await RemoteMerge.forTable(queue, table);
    expect(await merge.accepts(id, now.toLocal().add(const Duration(minutes: 1))), isTrue);
  });
}
