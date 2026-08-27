import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../config/app_config.dart';
import 'app_database.dart';

/// Apertura de la base en el navegador. **No cifra nada** — ver
/// `encrypted_connection.dart`, que es quien elige entre esta implementación y
/// la nativa.
///
/// Web no es plataforma objetivo: el producto es iOS y Android, y este
/// despliegue existe para enseñar pantallas. `RNF-15` habla del teléfono del
/// criador, donde sí hay datos suyos que proteger; aquí la base vive en el
/// IndexedDB del navegador que abrió la demostración. La clave que llega en
/// [open] se ignora a propósito: fingir que se aplica sería peor que no
/// cifrar, porque nadie volvería a mirarlo.
abstract final class EncryptedConnection {
  /// Mismo nombre que en el móvil para que la API no dependa de la plataforma.
  /// El sufijo describe la base del teléfono, no esta.
  static const String encryptedName = '${AppConfig.databaseName}_enc';

  static Future<QueryExecutor> open({required String key}) async =>
      driftDatabase(name: encryptedName, web: AppDatabase.webOptions);

  /// No hay base anterior sin cifrar que migrar: el navegador nunca tuvo una
  /// cifrada de la que distinguirla.
  static Future<void> migratePlainDatabase({required String key}) async {}
}
