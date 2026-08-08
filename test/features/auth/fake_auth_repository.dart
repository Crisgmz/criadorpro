import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/auth/model/country.dart';
import 'package:criadorpro/features/auth/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

/// Doble de [AuthRepository] para probar los ViewModels de entrada.
///
/// Se escribe a mano en lugar de generarlo: el proyecto no tiene librería de
/// dobles y el contrato es pequeño. Cada método guarda lo que recibió y
/// devuelve lo que se le haya configurado, que es todo lo que necesitan estas
/// pruebas.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.isEnabled = true, this.isSignedIn = false});

  @override
  bool isEnabled;

  @override
  bool isSignedIn;

  /// Lo que devolverá la próxima llamada. `null` = éxito.
  Failure? failure;

  // Registro de llamadas.
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int sendResetCalls = 0;
  int updatePasswordCalls = 0;

  String? lastEmail;
  String? lastPassword;
  String? lastFullName;
  String? lastPhone;
  Country? lastCountry;
  String? lastLocale;
  String? lastCode;
  VerificationPurpose? lastPurpose;

  /// Orden en el que se invocaron los métodos. `RF-AUT-13` exige que el cierre
  /// de sesión ocurra después de actualizar la contraseña, y esto lo verifica.
  final List<String> callOrder = [];

  Result<T> _result<T>(T value) {
    final pending = failure;
    return pending == null ? Ok(value) : Err(pending);
  }

  @override
  Future<Result<void>> signIn({required String email, required String password}) async {
    signInCalls++;
    callOrder.add('signIn');
    lastEmail = email;
    lastPassword = password;
    return _result(null);
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    required Country country,
    required String locale,
    String? phone,
  }) async {
    signUpCalls++;
    callOrder.add('signUp');
    lastEmail = email;
    lastPassword = password;
    lastFullName = fullName;
    lastCountry = country;
    lastPhone = phone;
    lastLocale = locale;
    return _result(SignUpOutcome.needsEmailConfirmation);
  }

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    callOrder.add('signOut');
    return const Ok(null);
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
    required VerificationPurpose purpose,
  }) async {
    verifyCalls++;
    callOrder.add('verifyCode');
    lastEmail = email;
    lastCode = code;
    lastPurpose = purpose;
    return _result(null);
  }

  @override
  Future<Result<void>> resendCode({
    required String email,
    required VerificationPurpose purpose,
  }) async {
    resendCalls++;
    callOrder.add('resendCode');
    lastEmail = email;
    lastPurpose = purpose;
    return _result(null);
  }

  @override
  Future<Result<void>> sendPasswordResetCode({required String email}) async {
    sendResetCalls++;
    callOrder.add('sendPasswordResetCode');
    lastEmail = email;
    return _result(null);
  }

  @override
  Future<Result<void>> updatePassword({required String password}) async {
    updatePasswordCalls++;
    callOrder.add('updatePassword');
    lastPassword = password;
    return _result(null);
  }

  @override
  Future<Result<void>> signInWithProvider(SocialProvider provider) async =>
      const Err(AuthFailure(reason: AuthFailureReason.providerUnavailable));

  @override
  String? get currentUserId => isSignedIn ? 'owner-1' : null;

  @override
  String? get currentEmail => isSignedIn ? 'criador@ejemplo.do' : null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();
}
