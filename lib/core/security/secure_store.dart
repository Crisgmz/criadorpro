import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén seguro del sistema — `RNF-14`.
///
/// Keychain en iOS y el Keystore de Android. Aquí van las dos cosas que no
/// pueden estar en claro en el dispositivo: la clave con la que se cifra la
/// base local y los tokens de sesión de Supabase.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage, Random? random})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // `first_unlock` y no `unlocked`: la sincronización en segundo
            // plano necesita abrir la base con el teléfono bloqueado.
            // `_this_device` impide que la clave viaje en una copia de iCloud.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            // Android no necesita ajustes: desde la v11 el almacén cifra con
            // AES-GCM respaldado por el Keystore sin tener que pedirlo.
          ),
      _random = random ?? Random.secure();

  static const String _databaseKeyName = 'db.encryption_key';

  final FlutterSecureStorage _storage;
  final Random _random;

  /// Clave de cifrado de la base, creándola la primera vez.
  ///
  /// **Si esta clave se pierde, los datos locales son irrecuperables.** No hay
  /// copia ni forma de derivarla: es aleatoria, vive solo en el almacén seguro
  /// del dispositivo y por eso no viaja en las copias de seguridad. Lo que
  /// protege al criador de perder su libro no es esta clave sino la
  /// sincronización con el servidor.
  Future<String> databaseKey() async {
    final existing = await _storage.read(key: _databaseKeyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final key = _generateKey();
    await _storage.write(key: _databaseKeyName, value: key);
    return key;
  }

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  /// 256 bits de `Random.secure()`, que en móvil sale del generador del
  /// sistema. En base64 para poder pasarla como texto al `PRAGMA key`.
  String _generateKey() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
