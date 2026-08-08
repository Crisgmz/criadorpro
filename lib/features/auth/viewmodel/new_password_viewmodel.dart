import '../../../core/base/base_viewmodel.dart';
import '../../../core/utils/validators.dart';
import '../model/password_strength.dart';
import '../repository/auth_repository.dart';

/// Pantalla 9 — nueva contraseña.
///
/// Llega aquí con la sesión que abrió la verificación del código de
/// recuperación. Al terminar, `RF-AUT-13` obliga a cerrar esa sesión y conducir
/// a iniciar sesión, no a la aplicación.
class NewPasswordViewModel extends BaseViewModel {
  NewPasswordViewModel(this._auth);

  final AuthRepository _auth;

  String _password = '';
  String _confirmation = '';
  ValidationError? _passwordError;
  ValidationError? _confirmationError;

  ValidationError? get passwordError => _passwordError;
  ValidationError? get confirmationError => _confirmationError;
  PasswordStrength get passwordStrength => PasswordStrength.of(_password);

  void setPassword(String value) {
    _password = value;
    if (_passwordError != null) _passwordError = null;
    safeNotify();
  }

  void setConfirmation(String value) {
    _confirmation = value;
    if (_confirmationError != null) {
      _confirmationError = null;
      safeNotify();
    }
  }

  void validatePassword() {
    _passwordError = Validators.password(_password);
    safeNotify();
  }

  void validateConfirmation() {
    _confirmationError = Validators.passwordConfirmation(_confirmation, _password);
    safeNotify();
  }

  /// Guarda la contraseña y cierra la sesión de recuperación. `true` si todo
  /// salió bien: la View muestra entonces el modal de éxito (pantalla 10) y
  /// lleva a iniciar sesión.
  Future<bool> submit() async {
    _passwordError = Validators.password(_password);
    _confirmationError = Validators.passwordConfirmation(_confirmation, _password);
    if (_passwordError != null || _confirmationError != null) {
      safeNotify();
      return false;
    }

    setLoading();
    final result = await _auth.updatePassword(password: _password);

    return result.fold(
      ok: (_) async {
        // Sin esto la sesión de recuperación quedaría viva y el usuario
        // entraría a la app sin volver a autenticarse — `RF-AUT-13`.
        await _auth.signOut();
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
