import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../config/app_config.dart';
import 'daos/birds_dao.dart';
import 'daos/clutches_dao.dart';
import 'daos/evaluations_dao.dart';
import 'daos/profiles_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/transactions_dao.dart';
import 'tables/birds.dart';
import 'tables/clutches.dart';
import 'tables/evaluations.dart';
import 'tables/profiles.dart';
import 'tables/sync_queue_entries.dart';
import 'tables/transactions.dart';

part 'app_database.g.dart';

/// Base local. Es la fuente de verdad de la UI: todo lo que se pinta sale de
/// aquí, y la sincronización solo alimenta esta base.
@DriftDatabase(
  tables: [Profiles, Birds, Clutches, Evaluations, Transactions, SyncQueueEntries],
  daos: [ProfilesDao, BirdsDao, ClutchesDao, EvaluationsDao, TransactionsDao, SyncQueueDao],
)
class AppDatabase extends _$AppDatabase {
  /// En tests, pásale un executor en memoria:
  /// `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: AppConfig.databaseName, web: _webOptions));

  /// Web **no es plataforma objetivo** —el producto es iOS y Android—, pero
  /// Chrome es con diferencia la forma más rápida de revisar una pantalla, y
  /// sin esto `driftDatabase` se niega a compilar allí.
  ///
  /// Los dos archivos viven en `web/` y se sirven como assets estáticos:
  /// `sqlite3.wasm` es el propio motor SQLite compilado, y `drift_worker.js`
  /// el worker que lo ejecuta fuera del hilo de la interfaz. Sus versiones van
  /// atadas a las de `sqlite3` y `drift` en `pubspec.lock`: al subir cualquiera
  /// de los dos paquetes hay que volver a descargarlos (ver README).
  static final _webOptions = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 — `profiles` alineado con el SRS: el alta ya manda nombre, teléfono,
      // país e idioma, y el onboarding necesitará `next_plate`.
      if (from < 2) {
        await m.addColumn(profiles, profiles.farmName);
        await m.addColumn(profiles, profiles.location);
        await m.addColumn(profiles, profiles.countryCode);
        await m.addColumn(profiles, profiles.locale);
        await m.addColumn(profiles, profiles.nextPlate);
        await m.addColumn(profiles, profiles.avatarUrl);

        // `breeder_name` y `country` desaparecen, pero lo que contenían es el
        // dato del usuario: se traslada antes de que la columna se pierda.
        await customStatement(
          'UPDATE profiles SET farm_name = breeder_name WHERE breeder_name IS NOT NULL',
        );
        await customStatement(
          'UPDATE profiles SET country_code = UPPER(SUBSTR(country, 1, 2)) '
          'WHERE country IS NOT NULL',
        );
        // SQLite no soporta DROP COLUMN en versiones antiguas; dejarlas
        // huérfanas es inocuo y la próxima descarga completa las ignora.
      }

      // v3 — la placa sustituye a la anilla. Es el cambio del que cuelga todo
      // el registro, y el esquema local difiere lo bastante como para que
      // recrear las tablas salga más barato y seguro que parchearlas: los
      // datos vuelven enteros en la siguiente bajada (`RF-SIN-08`).
      if (from < 3) {
        await m.deleteTable(birds.actualTableName);
        await m.deleteTable(clutches.actualTableName);
        await m.createTable(birds);
        await m.createTable(clutches);
        // La cola se vacía con las tablas: sus operaciones apuntan a filas que
        // ya no existen y con la forma antigua del payload. Quien repuebla es
        // la descarga completa que dispara `SyncService` al detectar que el
        // esquema cambió.
        await customStatement('DELETE FROM sync_queue_entries');
      }

      // v4 — pruebas de campo (`RF-PRU`). Tabla nueva: nada que migrar, y los
      // datos existentes no se tocan.
      if (from < 4) {
        await m.createTable(evaluations);
      }

      // v5 — contabilidad (`RF-CON`). Tabla nueva, nada que migrar.
      if (from < 5) {
        await m.createTable(transactions);
      }

      // v7 — marca de nacimiento y cintas de ala, como en el prototipo. La v6
      // había añadido `foot_mark` y `beak_mark`, que eran una lectura
      // equivocada del mismo dato; se quedan sin usar y sin borrar, porque
      // `RS-10` y el riesgo de migración del DDT piden que toda migración sea
      // compatible con la versión anterior de la app.
      if (from < 7) {
        await m.addColumn(birds, birds.birthMark);
        await m.addColumn(birds, birds.wingBandLeft);
        await m.addColumn(birds, birds.wingBandRight);
      }

      // v8 — tipo de cresta. Columna nueva y nula: lo registrado sigue igual.
      if (from < 8) {
        await m.addColumn(birds, birds.comb);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _repairMissingColumns();
    },
  );

  /// Red de seguridad: añade las columnas que el esquema declara y la base no
  /// tiene.
  ///
  /// Existe por un fallo real: la migración a base cifrada copiaba las tablas
  /// pero no `user_version`, así que Drift tomaba la base por nueva, no
  /// aplicaba ninguna migración y las columnas añadidas después nunca llegaban.
  /// La consulta fallaba con «no such column» en una pantalla concreta, meses
  /// más tarde y sin relación aparente con la causa.
  ///
  /// Solo añade columnas —nunca borra ni cambia tipos— y todas las del esquema
  /// son nulas o con valor por omisión, así que es seguro y repetible.
  /// SQLite es de tipado laxo, así que basta con la afinidad correcta. Se mapea
  /// a mano en lugar de pedírselo a Drift: su API para esto necesita un
  /// contexto de generación que aquí no existe.
  static String _sqlType(GeneratedColumn<Object> column) => switch (column) {
    GeneratedColumn<int>() => 'INTEGER',
    GeneratedColumn<bool>() => 'INTEGER',
    GeneratedColumn<double>() => 'REAL',
    GeneratedColumn<DateTime>() => 'INTEGER',
    GeneratedColumn<Uint8List>() => 'BLOB',
    _ => 'TEXT',
  };

  Future<void> _repairMissingColumns() async {
    for (final table in allTables) {
      final existing = {
        for (final row in await customSelect('PRAGMA table_info(${table.actualTableName})').get())
          row.read<String>('name'),
      };
      if (existing.isEmpty) continue;

      for (final column in table.$columns) {
        if (existing.contains(column.name)) continue;
        await customStatement(
          'ALTER TABLE ${table.actualTableName} ADD COLUMN ${column.name} ${_sqlType(column)}',
        );
      }
    }
  }
}
