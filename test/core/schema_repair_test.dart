import 'dart:io';

import 'package:criadorpro/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// La migración a base cifrada copiaba las tablas pero **no `user_version`**.
/// Drift tomaba la base por nueva, no aplicaba ninguna migración, y las
/// columnas añadidas después nunca llegaban: meses más tarde, una pantalla
/// concreta fallaba con «no such column» sin relación aparente con la causa.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('schema_repair'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('una base con la tabla vieja recupera las columnas que faltan', () async {
    final path = '${temp.path}/app.sqlite';

    // Lo que dejaba la migración rota: `birds` con el esquema de antes y la
    // versión de esquema a cero.
    final legacy = raw.sqlite3.open(path);
    legacy
      ..execute(
        'create table birds ('
        'id text not null, owner_id text not null, plate integer not null, '
        'name text, sex text not null, status text not null, '
        'created_at integer not null, updated_at integer not null, '
        'is_deleted integer not null default 0, is_dirty integer not null default 0, '
        'primary key (id))',
      )
      ..execute("insert into birds values ('b1','o1',7,'Cenizo','male','active',0,0,0,0)")
      ..execute('pragma user_version = 0;');
    legacy.close();

    // Abrirla con Drift dispara `beforeOpen`, que repara lo que falte.
    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    final columns = {
      for (final row in await db.customSelect('PRAGMA table_info(birds)').get())
        row.read<String>('name'),
    };

    // Las que se añadieron después de que la base se quedara congelada.
    expect(columns, contains('comb'));
    expect(columns, contains('birth_mark'));
    expect(columns, contains('wing_band_left'));
    expect(columns, contains('wing_band_right'));

    // Y lo que había sigue ahí: reparar no puede costar datos.
    final rows = await db.customSelect('select id, plate from birds').get();
    expect(rows, hasLength(1));
    expect(rows.single.read<int>('plate'), 7);
  });

  test('la consulta que fallaba ahora funciona', () async {
    final path = '${temp.path}/app2.sqlite';
    final legacy = raw.sqlite3.open(path);
    legacy
      ..execute(
        'create table birds ('
        'id text not null, owner_id text not null, plate integer not null, '
        'sex text not null, status text not null, '
        'created_at integer not null, updated_at integer not null, '
        'is_deleted integer not null default 0, is_dirty integer not null default 0, '
        'primary key (id))',
      )
      ..execute('pragma user_version = 0;');
    legacy.close();

    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Es la consulta del selector de plumaje y cresta, la que dejaba la hoja
    // en blanco.
    final usage = await db.birdsDao
        .watchTraitUsage(ownerId: 'o1', isComb: true)
        .first
        .timeout(const Duration(seconds: 5));

    expect(usage, isEmpty);
  });
}
