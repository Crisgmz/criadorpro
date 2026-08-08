import '../../../core/base/base_viewmodel.dart';
import '../../../core/utils/validators.dart';
import '../repository/auth_repository.dart';

/// Pantalla 7 — recuperar contraseña, paso del correo.
///
/// `RF-AUT-12`: la recuperación es gratuita y no depende del plan, y el copy de
/// la pantalla lo dice explícitamente.
class ForgotPasswordViewModel extends BaseViewModel {
  ForgotPasswordViewModel(this._auth);

  final AuthRepository _auth;

  String _email = '';
  ValidationError? _emailError;

  ValidationError? get emailError => _emailError;
  bool get isBackendConfigured => _auth.isEnabled;

  void setEmail(String value) {
    _email = value;
    if (_emailError != null) {
      _emailError = null;
      safeNotify();
    }
  }

  void validateEmail() {
    _emailError = Validators.email(_email);
    safeNotify();
  }

  /// Devuelve el correo normalizado si el envío salió bien, para llevarlo a la
  /// pantalla del código. `null` si falló.
  ///
  /// El resultado es el mismo exista o no la cuenta: revelar lo contrario
  /// convertiría esta pantalla en un detector de correos registrados, que es
  /// justo lo que `E-AUTH-01` evita en el inicio de sesión.
  Future<String?> submit() async {
    _emailError = Validators.email(_email);
    if (_emailError != null) {
      safeNotify();
      return null;
    }

    setLoading();
    final result = await _auth.sendPasswordResetCode(email: _email);

    return result.fold(
      ok: (_) {
        setReady();
        return Validators.normalizeEmail(_email);
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }
}
