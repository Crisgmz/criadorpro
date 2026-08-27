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
  /// **El mismo nombre de siempre**, no el `_enc` del teléfono.
  ///
  /// El nombre es lo que identifica la base en IndexedDB: cambiarlo no migra
  /// nada, abre una vacía. Quien ya hubiera registrado ejemplares en el
  /// navegador los vería desaparecer en el siguiente despliegue, sin error y
  /// sin forma de recuperarlos desde la interfaz. El sufijo `_enc` existe en
  /// el móvil para distinguir el archivo cifrado del que había en claro, y
  /// aquí no hay ni lo uno ni lo otro.
  static const String databaseName = AppConfig.databaseName;

  static Future<QueryExecutor> open({required String key}) async =>
      driftDatabase(name: databaseName, web: AppDatabase.webOptions);

  /// No hay base anterior sin cifrar que migrar: el navegador nunca tuvo una
  /// cifrada de la que distinguirla.
  static Future<void> migratePlainDatabase({required String key}) async {}
}
