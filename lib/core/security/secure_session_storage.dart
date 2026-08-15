import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_store.dart';

/// Sesión de Supabase en el almacén seguro del sistema — `RNF-14`.
///
/// Por omisión, `supabase_flutter` guarda la sesión en `SharedPreferences`, que
/// en Android es un XML legible con el dispositivo rooteado y en iOS un plist
/// dentro del contenedor. El token de refresco vale tanto como la contraseña
/// —permite emitir tokens nuevos sin volver a autenticarse—, así que va al
/// Keychain o al Keystore.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._store);

  static const String _sessionKey = 'auth.session';

  final SecureStore _store;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _store.read(_sessionKey)) != null;

  @override
  Future<String?> accessToken() async {
    final raw = await _store.read(_sessionKey);
    if (raw == null) return null;

    // La sesión se guarda entera; de ella se extrae el token que pide el SDK.
    // Un JSON corrupto se trata como «no hay sesión»: obliga a entrar de nuevo,
    // que es molesto pero seguro, en lugar de tumbar el arranque.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded['access_token'] as String? ?? raw;
      }
    } on FormatException {
      return null;
    }
    return raw;
  }

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(_sessionKey, persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(_sessionKey);
}
