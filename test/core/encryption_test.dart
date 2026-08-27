import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// `RNF-15` — la base local va cifrada.
///
/// Lo que se comprueba aquí no es código propio sino una **premisa de la que
/// depende todo**: que la compilación de SQLite que empaqueta la app admite
/// cifrado. Si alguien quita el `hooks.user_defines` del `pubspec.yaml`, el
/// `PRAGMA key` se ignora en silencio, la base queda en claro y nada falla.
/// Esta prueba es lo único que lo delataría.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('criadorpro_cipher'));
  tearDown(() => temp.deleteSync(recursive: true));

  String pathFor(String name) => '${temp.path}/$name.sqlite';

  test('la compilación de SQLite empaquetada admite cifrado', () {
    final db = sqlite3.openInMemory();
    final version = db.select('select sqlite3mc_version();');
    db.close();

    // Sin la variante SQLite3MultipleCiphers, esta función no existe.
    expect(version, isNotEmpty);
  });

  test('los datos no quedan legibles en el archivo', () {
    final path = pathFor('cifrada');

    final db = sqlite3.open(path)..execute("pragma key = 'clave-de-prueba';");
    db
      ..execute('create table birds (id text primary key, name text);')
      ..execute("insert into birds values ('b1', 'Giro Colorado');")
      ..close();

    final bytes = File(path).readAsBytesSync();
    final asText = String.fromCharCodes(bytes);

    // Una base sin cifrar empieza por «SQLite format 3» y guarda el texto tal
    // cual: en un teléfono rooteado se leería con un editor hexadecimal.
    expect(asText.startsWith('SQLite format 3'), isFalse);
    expect(asText.contains('Giro Colorado'), isFalse);
  });

  test('sin la clave correcta la base no se abre', () {
    final path = pathFor('protegida');

    final db = sqlite3.open(path)..execute("pragma key = 'la-buena';");
    db
      ..execute('create table t (v text);')
      ..execute("insert into t values ('dato');")
      ..close();

    // Sin clave.
    expect(() => sqlite3.open(path).select('select * from t;'), throwsA(isA<SqliteException>()));

    // Con la clave equivocada.
    expect(() {
      final wrong = sqlite3.open(path)..execute("pragma key = 'la-mala';");
      wrong.select('select * from t;');
    }, throwsA(isA<SqliteException>()));

    // Con la buena.
    final ok = sqlite3.open(path)..execute("pragma key = 'la-buena';");
    expect(ok.select('select * from t;'), hasLength(1));
    ok.close();
  });

  test('la migración conserva los datos de una base sin cifrar', () {
    final plainPath = pathFor('plana');
    final encryptedPath = pathFor('cifrada');
    const key = 'clave-de-migracion';

    // Base como la que tendría un dispositivo con la app ya instalada.
    final plain = sqlite3.open(plainPath);
    plain.execute('create table birds (id text primary key, plate integer);');
    // La versión del esquema es parte de los datos: sin ella, Drift toma la
    // base migrada por nueva y no vuelve a aplicar ninguna migración.
    plain.execute('pragma user_version = 7;');
    for (var i = 1; i <= 5; i++) {
      plain.execute('insert into birds values (?, ?);', ['b$i', i]);
    }
    plain.close();

    expect(
      String.fromCharCodes(File(plainPath).readAsBytesSync().take(15)),
      'SQLite format 3',
      reason: 'la de partida debe estar en claro',
    );

    // El mismo procedimiento que usa `EncryptedConnection`: adjuntar la plana
    // y copiar tabla por tabla. `sqlcipher_export` no existe en sqlite3mc.
    final destination = sqlite3.open(encryptedPath)..execute("pragma key = '$key';");
    destination.execute("attach database '$plainPath' as plain key '';");
    final create =
        destination
                .select(
                  "select sql from plain.sqlite_master where type = 'table' and name = 'birds';",
                )
                .first['sql']
            as String;
    destination
      ..execute(create.replaceFirst('CREATE TABLE ', 'CREATE TABLE main.'))
      ..execute('insert into main.birds select * from plain.birds;')
      ..execute(
        'pragma user_version = '
        '${destination.select('pragma plain.user_version;').first.values.first};',
      )
      ..execute('detach database plain;')
      ..close();

    final migrated = sqlite3.open(encryptedPath)..execute("pragma key = '$key';");
    expect(migrated.select('select count(*) c from birds;').first['c'], 5);
    expect(
      migrated.select('pragma user_version;').first.values.first,
      7,
      reason: 'la versión de esquema viaja con los datos',
    );
    migrated.close();

    // Y el resultado está cifrado de verdad.
    expect(
      String.fromCharCodes(File(encryptedPath).readAsBytesSync().take(15)),
      isNot('SQLite format 3'),
    );
  });
}
