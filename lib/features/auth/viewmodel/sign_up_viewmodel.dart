import '../../../core/base/base_viewmodel.dart';
import '../../../core/utils/validators.dart';
import '../model/country.dart';
import '../model/password_strength.dart';
import '../repository/auth_repository.dart';

/// Pantalla 4 — crear cuenta.
///
/// `RF-AUT-05` marca la pauta de validación: los `set*` solo guardan y retiran
/// el error que hubiera; el error se calcula en los `validate*`, que la View
/// dispara **al perder el foco**, nunca mientras se escribe.
class SignUpViewModel extends BaseViewModel {
  SignUpViewModel(this._auth);

  final AuthRepository _auth;

  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _password = '';
  String _passwordConfirmation = '';
  Country _country = Country.fallback;
  bool _acceptedTerms = false;

  ValidationError? _fullNameError;
  ValidationError? _emailError;
  ValidationError? _phoneError;
  ValidationError? _passwordError;
  ValidationError? _passwordConfirmationError;

  String get email => _email;
  Country get country => _country;
  bool get acceptedTerms => _acceptedTerms;
  bool get isBackendConfigured => _auth.isEnabled;

  ValidationError? get fullNameError => _fullNameError;
  ValidationError? get emailError => _emailError;
  ValidationError? get phoneError => _phoneError;
  ValidationError? get passwordError => _passwordError;
  ValidationError? get passwordConfirmationError => _passwordConfirmationError;

  /// Informativo: `RV-02` deja claro que el medidor no bloquea por sí solo.
  PasswordStrength get passwordStrength => PasswordStrength.of(_password);

  /// `RF-AUT-04` — el botón permanece deshabilitado hasta aceptar los términos
  /// de forma explícita (`RV-05`).
  bool get canSubmit => _acceptedTerms && isBackendConfigured && !isLoading;

  // --- Captura -------------------------------------------------------------

  void setFullName(String value) {
    _fullName = value;
    if (_fullNameError != null) {
      _fullNameError = null;
      safeNotify();
    }
  }

  void setEmail(String value) {
    _email = value;
    if (_emailError != null) {
      _emailError = null;
      safeNotify();
    }
  }

  void setPhone(String value) {
    _phone = value;
    if (_phoneError != null) {
      _phoneError = null;
      safeNotify();
    }
  }

  void setPassword(String value) {
    _password = value;
    // El medidor se repinta con cada pulsación; el mensaje de error, no.
    if (_passwordError != null) _passwordError = null;
    safeNotify();
  }

  void setPasswordConfirmation(String value) {
    _passwordConfirmation = value;
    if (_passwordConfirmationError != null) {
      _passwordConfirmationError = null;
      safeNotify();
    }
  }

  void setCountry(Country value) {
    if (_country == value) return;
    _country = value;
    // Cambia el prefijo, así que el número escrito puede dejar de ser válido.
    _phoneError = null;
    safeNotify();
  }

  void setAcceptedTerms({required bool value}) {
    if (_acceptedTerms == value) return;
    _acceptedTerms = value;
    safeNotify();
  }

  // --- Validación al perder el foco (RF-AUT-05) ---------------------------

  void validateFullName() {
    _fullNameError = Validators.fullName(_fullName);
    safeNotify();
  }

  void validateEmail() {
    _emailError = Validators.email(_email);
    safeNotify();
  }

  void validatePhone() {
    _phoneError = Validators.optionalPhone(_phone);
    safeNotify();
  }

  void validatePassword() {
    _passwordError = Validators.password(_password);
    safeNotify();
  }

  void validatePasswordConfirmation() {
    _passwordConfirmationError = Validators.passwordConfirmation(_passwordConfirmation, _password);
    safeNotify();
  }

  // --- Envío ---------------------------------------------------------------

  /// Devuelve el correo normalizado si el alta salió bien, para que la View
  /// navegue a la pantalla de verificación. `null` significa que falló y que
  /// hay un error que mostrar.
  ///
  /// El [locale] llega desde la View porque es la única capa que sabe en qué
  /// idioma se está viendo la app. Se guarda en el perfil para que los correos
  /// y el panel del criadero salgan en ese idioma desde el primer día.
  Future<String?> submit({required String locale}) async {
    if (!_validateAll()) return null;

    setLoading();
    final result = await _auth.signUp(
      email: _email,
      password: _password,
      fullName: _fullName,
      country: _country,
      locale: locale,
      phone: _phone,
    );

    return result.fold(
      // Con la confirmación de correo activada Supabase no abre sesión, así que
      // la pantalla siguiente son las seis casillas. Si por configuración ya
      // hubiera sesión, el router redirige solo a Inicio.
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

  bool _validateAll() {
    _fullNameError = Validators.fullName(_fullName);
    _emailError = Validators.email(_email);
    _phoneError = Validators.optionalPhone(_phone);
    _passwordError = Validators.password(_password);
    _passwordConfirmationError = Validators.passwordConfirmation(_passwordConfirmation, _password);
    safeNotify();

    return _fullNameError == null &&
        _emailError == null &&
        _phoneError == null &&
        _passwordError == null &&
        _passwordConfirmationError == null;
  }
}
