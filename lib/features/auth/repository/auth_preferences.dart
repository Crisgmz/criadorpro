import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del flujo de entrada.
///
/// Nada de esto es secreto —ni el correo recordado ni el identificador del
/// último criadero son credenciales— así que vive en `SharedPreferences`. Los
/// tokens de sesión sí son secretos y van al almacén seguro del sistema
/// (`RNF-14`, `SecureSessionStorage`); no pasan por aquí.
class AuthPreferences {
  AuthPreferences(this._preferences);

  static const String _onboardingKey = 'onboarding.completed';
  static const String _rememberedEmailKey = 'auth.remembered_email';
  static const String _lastOwnerKey = 'auth.last_owner_id';

  final SharedPreferences _preferences;

  // --- Onboarding (RF-AUT-02) ---------------------------------------------

  /// `RF-AUT-02` lo limita a una vez **por instalación**, que es exactamente la
  /// vida de `SharedPreferences`: sobrevive a cerrar sesión y desaparece al
  /// desinstalar. No va atado a la cuenta a propósito — son las tres láminas
  /// que explican el producto, no un paso del alta.
  bool get hasSeenOnboarding => _preferences.getBool(_onboardingKey) ?? false;

  Future<void> markOnboardingSeen() => _preferences.setBool(_onboardingKey, true);

  // --- «Recordarme» de la pantalla 6 --------------------------------------

  /// Solo el correo. La sesión ya persiste sola entre aperturas (`RF-AUT-14`),
  /// así que lo que este control aporta es no volver a escribirlo cuando el
  /// usuario sí cerró sesión.
  String? get rememberedEmail => _preferences.getString(_rememberedEmailKey);

  Future<void> rememberEmail(String email) => _preferences.setString(_rememberedEmailKey, email);

  Future<void> forgetEmail() => _preferences.remove(_rememberedEmailKey);

  // --- Último criadero en este dispositivo (RF-AUT-15) --------------------

  /// Quién usó por última vez esta instalación.
  ///
  /// Desde que los datos locales sobreviven al cierre de sesión, hace falta
  /// saber si quien entra es el mismo de antes: en un teléfono compartido, dos
  /// criadores no pueden heredar la base del otro. No es secreto —es un uuid
  /// sin valor por sí solo— y por eso no ocupa sitio en el almacén seguro.
  String? get lastOwnerId => _preferences.getString(_lastOwnerKey);

  Future<void> rememberOwner(String ownerId) => _preferences.setString(_lastOwnerKey, ownerId);

  /// Olvida al último propietario. Solo al borrar la cuenta: al cerrar sesión
  /// se conserva, porque es lo que distingue «vuelve el mismo criadero» de
  /// «entra otro» y decide si hay que limpiar la base (`RF-AUT-15`).
  Future<void> forgetOwner() => _preferences.remove(_lastOwnerKey);
}
