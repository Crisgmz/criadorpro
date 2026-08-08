import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/validators.dart';
import '../repository/auth_repository.dart';

/// Clave del provider `family`. Es un record porque su igualdad es estructural:
/// dos pantallas con el mismo correo y propósito comparten ViewModel, y dos
/// distintas no se pisan la cuenta regresiva.
typedef VerifyCodeArgs = ({String email, VerificationPurpose purpose});

/// Pantallas 5 y 8 — las seis casillas del código.
///
/// Un solo ViewModel para las dos porque el comportamiento es idéntico y el
/// prototipo lo declara explícitamente («mismo componente que la pantalla 5»);
/// lo único que cambia es el [VerificationPurpose] y, con él, a dónde se va
/// después. La cuenta regresiva de reenvío (`RF-AUT-08`) vive aquí.
class VerifyCodeViewModel extends BaseViewModel {
  VerifyCodeViewModel({required AuthRepository auth, required this.email, required this.purpose})
    : _auth = auth {
    _startCooldown();
  }

  final AuthRepository _auth;
  final String email;
  final VerificationPurpose purpose;

  Timer? _timer;
  int _secondsLeft = 0;
  String _code = '';
  ValidationError? _codeError;

  String get code => _code;
  ValidationError? get codeError => _codeError;

  /// Segundos que faltan para poder reenviar. Cero significa habilitado.
  int get secondsLeft => _secondsLeft;
  bool get canResend => _secondsLeft == 0 && !isLoading;

  bool get isComplete => _code.length == AppConfig.verificationCodeLength;

  void setCode(String value) {
    _code = value.trim();
    if (_codeError != null) _codeError = null;
    safeNotify();
  }

  /// Verifica el código. `true` si la verificación fue correcta.
  ///
  /// En el alta esto abre sesión y el router redirige solo; en la recuperación
  /// deja la sesión que habilita el cambio de contraseña, y es la View la que
  /// navega a la pantalla 9.
  Future<bool> verify() async {
    _codeError = Validators.verificationCode(_code);
    if (_codeError != null) {
      safeNotify();
      return false;
    }

    setLoading();
    final result = await _auth.verifyCode(email: email, code: _code, purpose: purpose);

    return result.fold(
      ok: (_) {
        setReady();
        return true;
      },
      err: (failure) {
        setFailure(failure);
        // Un código vencido o incorrecto habilita el reenvío de inmediato,
        // sin esperar la cuenta regresiva (CU-01, alterno B).
        if (failure case AuthFailure(
          :final reason,
        ) when reason == AuthFailureReason.codeExpired || reason == AuthFailureReason.codeInvalid) {
          _stopCooldown();
        }
        return false;
      },
    );
  }

  /// `RF-AUT-08` — reenvía y vuelve a arrancar la cuenta regresiva.
  Future<void> resend() async {
    if (!canResend) return;

    setLoading();
    final result = await _auth.resendCode(email: email, purpose: purpose);
    result.fold(
      ok: (_) {
        setReady();
        _code = '';
        _startCooldown();
      },
      err: setFailure,
    );
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = AppConfig.resendCodeCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        _secondsLeft = 0;
        timer.cancel();
      }
      safeNotify();
    });
    safeNotify();
  }

  void _stopCooldown() {
    _timer?.cancel();
    _secondsLeft = 0;
    safeNotify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
