import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../security/secure_session_storage.dart';
import '../security/secure_store.dart';

/// Envoltorio de Supabase que tolera no estar configurado.
///
/// Si faltan las variables de entorno la app sigue arrancando y funciona
/// contra Drift; solo se desactivan login y sincronización. Así el proyecto se
/// puede clonar y ejecutar sin credenciales.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient? _client;

  /// Inicializa Supabase si hay credenciales. Se llama una vez desde `main`.
  static Future<SupabaseService> initialize({SecureStore? secureStore}) async {
    if (!Env.isSupabaseConfigured) return SupabaseService(null);
    // `publishableKey` sustituye al antiguo `anonKey`; acepta tanto la clave
    // `anon` heredada como las nuevas `sb_publishable_...`.
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      // `RNF-14`: el token de refresco vale tanto como la contraseña, así que
      // no puede quedarse en `SharedPreferences`.
      authOptions: secureStore == null
          ? const FlutterAuthClientOptions()
          : FlutterAuthClientOptions(localStorage: SecureSessionStorage(secureStore)),
    );
    return SupabaseService(Supabase.instance.client);
  }

  bool get isEnabled => _client != null;

  SupabaseClient get client {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase no está configurado. Ejecuta con --dart-define=SUPABASE_URL=... '
        'y --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    return client;
  }

  User? get currentUser => _client?.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  bool get hasSession => _client?.auth.currentSession != null;

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();
}
