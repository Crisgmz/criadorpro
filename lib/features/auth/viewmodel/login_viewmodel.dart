import '../../../core/base/base_viewmodel.dart';
import '../../../core/utils/validators.dart';
import '../repository/auth_preferences.dart';
import '../repository/auth_repository.dart';

/// Pantalla 6 — iniciar sesión.
///
/// Solo entra: el alta tiene su propia pantalla desde que el flujo se abrió en
/// las diez de `RF-AUT`.
class LoginViewModel extends BaseViewModel {
  LoginViewModel({required AuthRepository auth, required AuthPreferences preferences})
    : _auth = auth,
      _preferences = preferences {
    final remembered = _preferences.rememberedEmail;
    if (remembered != null) {
      _email = remembered;
      _rememberMe = true;
    }
  }

  final AuthRepository _auth;
  final AuthPreferences _preferences;

  String _email = '';
  String _password = '';
  bool _rememberMe = false;
  ValidationError? _emailError;
  ValidationError? _passwordError;

  /// Correo con el que arranca el campo, si la última vez se marcó «recordarme».
  String get initialEmail => _email;
  bool get rememberMe => _rememberMe;
  bool get isBackendConfigured => _auth.isEnabled;
  ValidationError? get emailError => _emailError;
  ValidationError? get passwordError => _passwordError;

  void setEmail(String value) {
    _email = value;
    if (_emailError != null) {
      _emailError = null;
      safeNotify();
    }
  }

  void setPassword(String value) {
    _password = value;
    if (_passwordError != null) {
      _passwordError = null;
      safeNotify();
    }
  }

  void setRememberMe({required bool value}) {
    if (_rememberMe == value) return;
    _rememberMe = value;
    safeNotify();
  }

  // `RF-AUT-05` — al perder el foco, nunca mientras se escribe.
  void validateEmail() {
    _emailError = Validators.email(_email);
    safeNotify();
  }

  void validatePassword() {
    // Aquí solo se comprueba que haya algo escrito: exigir `RV-02` a quien
    // intenta entrar delataría el formato de las contraseñas válidas, y una
    // cuenta antigua podría no cumplirlo.
    _passwordError = Validators.required(_password);
    safeNotify();
  }

  /// `true` si la sesión quedó abierta. El router escucha el cambio y redirige.
  Future<bool> submit() async {
    _emailError = Validators.email(_email);
    _passwordError = Validators.required(_password);
    if (_emailError != null || _passwordError != null) {
      safeNotify();
      return false;
    }

    setLoading();
    final result = await _auth.signIn(email: _email, password: _password);

    return result.fold(
      ok: (_) async {
        if (_rememberMe) {
          await _preferences.rememberEmail(Validators.normalizeEmail(_email));
        } else {
          await _preferences.forgetEmail();
        }
        setReady();
        return true;
      },
      err: (failure) async {
        setFailure(failure);
        return false;
      },
    );
  }
}
