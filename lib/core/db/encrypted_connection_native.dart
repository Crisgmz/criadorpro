import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../config/app_config.dart';

/// Apertura de la base local cifrada en iOS y Android — `RNF-15`.
///
/// Este archivo **no se compila para web**: importa `package:sqlite3`, que
/// arrastra `dart:ffi`. Quien elige entre esta implementación y la del
/// navegador es `encrypted_connection.dart`, y es por ahí por donde hay que
/// importarla.
///
/// El cifrado no lo aporta un paquete de Flutter sino la propia compilación de
/// SQLite: el `hooks.user_defines` del `pubspec.yaml` pide la variante
/// SQLite3MultipleCiphers en lugar de la normal. Sin esa línea, el `PRAGMA key`
/// se ignora en silencio y la base queda **en claro sin avisar de nada**, que
/// es el peor resultado posible.
abstract final class EncryptedConnection {
  /// Archivo cifrado. Nombre distinto del de la base plana para que la
  /// migración pueda mirar los dos a la vez y no se pisen.
  static const String encryptedName = '${AppConfig.databaseName}_enc';

  /// Los primeros bytes de una base SQLite sin cifrar. Al cifrarla, la cabecera
  /// también se cifra, así que basta leerla para saber cuál es cuál.
  static const String _plainHeader = 'SQLite format 3';

  /// Orden de copia. Las tablas con dependientes van primero, por si algún día
  /// se activan las claves foráneas.
  ///
  /// Esta lista **no decide qué se copia**: eso lo dice la base de origen. Aquí
  /// solo se declara qué va antes; lo que no esté nombrado se copia después.
  /// Era una lista cerrada —`profiles`, `birds`, `clutches` y la cola— y por
  /// tanto se quedó atrás en cuanto llegaron pruebas de campo, contabilidad,
  /// empleomanía y pesadas: un teléfono que migrara hoy perdería esos cuatro
  /// módulos enteros, en silencio y sin nada que fallara. Deducirlo del origen
  /// es lo único que no puede quedarse viejo.
  static const List<String> _copyFirst = ['profiles', 'birds', 'clutches', 'employees'];

  /// Abre la base cifrada, migrando la anterior sin cifrar si la hubiera.
  static Future<QueryExecutor> open({required String key}) async {
    await migratePlainDatabase(key: key);

    return driftDatabase(
      name: encryptedName,
      native: DriftNativeOptions(
        // Se ejecuta en el isolate donde vive la conexión, no aquí: por eso
        // solo puede capturar valores enviables entre isolates, y `key` lo es.
        setup: (db) => db.execute("pragma key = '$key';"),
      ),
    );
  }

  /// Pasa los datos de la base sin cifrar a la cifrada y borra la vieja.
  ///
  /// Solo actúa en dispositivos que ya tenían la app antes del cifrado. Se hace
  /// copiando tabla por tabla y no con `sqlcipher_export`, que no existe en
  /// SQLite3MultipleCiphers.
  ///
  /// El orden importa y es deliberado: la base plana **no se borra hasta que la
  /// cifrada está escrita y verificada**. Si algo falla a mitad, el criador se
  /// queda con sus datos donde estaban.
  static Future<void> migratePlainDatabase({required String key}) async {
    final directory = await getApplicationDocumentsDirectory();
    await migrateFiles(
      key: key,
      plainFile: File(p.join(directory.path, '${AppConfig.databaseName}.sqlite')),
      encryptedFile: File(p.join(directory.path, '$encryptedName.sqlite')),
    );
  }

  /// El cuerpo de la migración, con los archivos ya resueltos.
  ///
  /// Se separa de [migratePlainDatabase] para poder probarlo: resolver la
  /// carpeta de documentos exige el plugin `path_provider`, y sin este corte la
  /// prueba tenía que reimplementar la copia en vez de ejercitarla — que es
  /// justo cómo una lista de tablas incompleta pasó desapercibida.
  @visibleForTesting
  static Future<void> migrateFiles({
    required String key,
    required File plainFile,
    required File encryptedFile,
  }) async {
    if (!plainFile.existsSync()) return;
    // Si ya hay base cifrada, la plana es un resto de una migración anterior
    // que no llegó a borrarla. Se retira sin copiar nada: sus datos ya están.
    if (encryptedFile.existsSync()) {
      await _deleteDatabaseFiles(plainFile);
      return;
    }
    if (!_isPlain(plainFile)) return;

    Database? destination;
    try {
      destination = sqlite3.open(encryptedFile.path)..execute("pragma key = '$key';");
      destination.execute("attach database '${plainFile.path}' as plain key '';");

      // El esquema se copia tal cual está en la base vieja, sin pasar por las
      // migraciones de Drift: se copian los datos que había, y Drift ya
      // actualizará el esquema al abrir si su versión ha cambiado.
      //
      // `sqlite_%` deja fuera las tablas internas de SQLite —`sqlite_sequence`
      // entre ellas—, que se recrean solas y no admiten un CREATE explícito.
      final found = destination.select(
        'select name, sql from plain.sqlite_master '
        "where type = 'table' and name not like 'sqlite_%' and sql is not null;",
      );
      final schema = {for (final row in found) row['name'] as String: row['sql'] as String};

      final order = [
        ..._copyFirst.where(schema.containsKey),
        ...schema.keys.where((name) => !_copyFirst.contains(name)),
      ];

      for (final table in order) {
        destination
          ..execute(
            schema[table]!.replaceFirst(
              RegExp('CREATE TABLE ', caseSensitive: false),
              'CREATE TABLE main.',
            ),
          )
          ..execute('insert into main."$table" select * from plain."$table";');
      }

      // **Imprescindible**: sin copiar la versión del esquema, la base cifrada
      // nace en 0. Drift la toma por nueva, ejecuta `onCreate` sobre unas
      // tablas que ya existen —y que `createAll` no toca— y a partir de ahí no
      // aplica ninguna migración. La tabla se queda con el esquema viejo para
      // siempre y cualquier columna nueva falla con «no such column».
      final version = destination.select('pragma plain.user_version;').first.values.first;
      destination
        ..execute('pragma user_version = $version;')
        ..execute('detach database plain;');
    } on SqliteException {
      // Migración fallida: se retira la copia a medias y se deja intacta la
      // base original. Peor que no migrar es quedarse con las dos incompletas.
      destination?.close();
      destination = null;
      if (encryptedFile.existsSync()) await _deleteDatabaseFiles(encryptedFile);
      return;
    } finally {
      destination?.close();
    }

    // Solo ahora, con la cifrada escrita y cerrada, se borra la vieja.
    await _deleteDatabaseFiles(plainFile);
  }

  /// `true` si el archivo es una base SQLite **sin cifrar**.
  static bool _isPlain(File file) {
    final handle = file.openSync();
    try {
      final header = String.fromCharCodes(handle.readSync(_plainHeader.length));
      return header == _plainHeader;
    } finally {
      handle.closeSync();
    }
  }

  /// Borra la base y sus archivos auxiliares: dejar el `-wal` de una base que
  /// ya no existe confunde a SQLite en el próximo arranque.
  static Future<void> _deleteDatabaseFiles(File database) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('${database.path}$suffix');
      if (file.existsSync()) await file.delete();
    }
  }
}
