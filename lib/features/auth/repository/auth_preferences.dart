import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del flujo de entrada.
///
/// Nada de esto es secreto —el correo recordado es una comodidad, no una
/// credencial— así que vive en `SharedPreferences`. Los tokens de sesión los
/// guarda Supabase y, según `RNF-14`, deben acabar en el almacén seguro del
/// sistema: eso está pendiente y no pasa por aquí.
class AuthPreferences {
  AuthPreferences(this._preferences);

  static const String _onboardingKey = 'onboarding.completed';
  static const String _rememberedEmailKey = 'auth.remembered_email';

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
}
