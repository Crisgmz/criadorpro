import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';

/// «Descargar mis datos» — pantalla 25.
///
/// El diseño lo pone justo antes de eliminar la cuenta, y es donde debe estar:
/// el borrado es irreversible y no hay copia, así que ofrecer el libro entero
/// antes es la diferencia entre perderlo y llevárselo.
///
/// Sale en **JSON y no en PDF**: esto no es un documento para enseñar, es el
/// libro del criador para que se lo lleve. Un PDF de dos mil movimientos no se
/// puede volver a leer con nada; un JSON sí.
///
/// Todo se lee de **Drift**, no del servidor: es la fuente de verdad
/// (`RF-SIN-01`) y así el respaldo funciona sin señal — que es justo cuando el
/// criador va a querer bajárselo antes de borrar.
class BackupService {
  BackupService({required AppDatabase database, BackupTarget target = const ShareBackupTarget()})
    : _database = database,
      _target = target;

  final AppDatabase _database;
  final BackupTarget _target;

  /// Versión del formato. Va dentro del archivo para que dentro de dos años se
  /// sepa qué se está leyendo.
  static const int formatVersion = 1;

  /// Arma el respaldo y lo entrega. Devuelve cuántos registros lleva.
  Future<int> export({required String ownerId, required DateTime now}) async {
    final tables = <String, List<Map<String, dynamic>>>{};
    var count = 0;

    for (final table in _database.allTables) {
      // La cola de sincronización no es del criador: es fontanería de la app y
      // no significa nada fuera de este teléfono.
      if (table.actualTableName == 'sync_queue_entries') continue;

      final rows = await _database.customSelect('SELECT * FROM ${table.actualTableName}').get();
      final data = <Map<String, dynamic>>[];

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row.data);
        // Cada tabla filtra por su propietario. `profiles` lo lleva en `id`.
        final owner = map['owner_id'] ?? map['id'];
        if (owner != ownerId) continue;

        // Las rutas locales no se llevan: apuntan a este teléfono y en el
        // respaldo solo serían ruido que confunde.
        map.remove('photo_path');
        map.remove('is_dirty');
        data.add(map);
      }

      if (data.isEmpty) continue;
      tables[table.actualTableName] = data;
      count += data.length;
    }

    final payload = <String, dynamic>{
      'format': formatVersion,
      'app': 'Criador Pro',
      'exportedAt': now.toUtc().toIso8601String(),
      'ownerId': ownerId,
      'records': count,
      'tables': tables,
    };

    // Con sangría: el respaldo se abre alguna vez a mano, y un JSON en una sola
    // línea de dos megas no lo lee nadie.
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
    final fileName = 'criadorpro-respaldo-${_stamp(now)}.json';

    await _target.share(bytes: bytes, fileName: fileName);
    return count;
  }

  static String _stamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Cómo se entrega el respaldo.
///
/// Detrás de una interfaz para poder sustituirlo en pruebas: abrir la hoja de
/// compartir del sistema dejaría el test esperando a un humano.
abstract interface class BackupTarget {
  Future<void> share({required List<int> bytes, required String fileName});
}

class ShareBackupTarget implements BackupTarget {
  const ShareBackupTarget();

  @override
  Future<void> share({required List<int> bytes, required String fileName}) async {
    // Se escribe a un temporal y se comparte el archivo: la hoja del sistema
    // necesita una ruta, y así el criador lo manda a donde quiera —correo,
    // Drive, WhatsApp— en vez de dejarlo en una carpeta que tendría que buscar.
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
