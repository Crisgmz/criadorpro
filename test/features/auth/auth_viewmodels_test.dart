import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/utils/validators.dart';
import 'package:criadorpro/features/auth/model/country.dart';
import 'package:criadorpro/features/auth/model/password_strength.dart';
import 'package:criadorpro/features/auth/repository/auth_preferences.dart';
import 'package:criadorpro/features/auth/repository/auth_repository.dart';
import 'package:criadorpro/features/auth/viewmodel/forgot_password_viewmodel.dart';
import 'package:criadorpro/features/auth/viewmodel/login_viewmodel.dart';
import 'package:criadorpro/features/auth/viewmodel/new_password_viewmodel.dart';
import 'package:criadorpro/features/auth/viewmodel/sign_up_viewmodel.dart';
import 'package:criadorpro/features/auth/viewmodel/splash_viewmodel.dart';
import 'package:criadorpro/features/auth/viewmodel/verify_code_viewmodel.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late AuthPreferences preferences;

  setUp(() async {
    auth = FakeAuthRepository();
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(await SharedPreferences.getInstance());
  });

  /// Rellena el formulario de alta con datos que pasan todas las validaciones.
  void fillValidSignUp(SignUpViewModel viewModel) {
    viewModel
      ..setFullName('Ramón Peña')
      ..setEmail('criador@ejemplo.do')
      ..setPhone('8095551234')
      ..setPassword('gallera1')
      ..setPasswordConfirmation('gallera1')
      ..setAcceptedTerms(value: true);
  }

  group('SplashViewModel · RF-AUT-01', () {
    test('con sesión abierta va a Inicio', () async {
      auth.isSignedIn = true;
      final viewModel = SplashViewModel(auth: auth, preferences: preferences);

      expect(await viewModel.resolve(), SplashDestination.home);
    });

    test('en el primer uso va al onboarding', () async {
      final viewModel = SplashViewModel(auth: auth, preferences: preferences);

      expect(await viewModel.resolve(), SplashDestination.onboarding);
    });

    test('si el onboarding ya se vio va a bienvenida', () async {
      await preferences.markOnboardingSeen();
      final viewModel = SplashViewModel(auth: auth, preferences: preferences);

      expect(await viewModel.resolve(), SplashDestination.welcome);
    });
  });

  group('SignUpViewModel', () {
    test('RF-AUT-04 · no se puede enviar sin aceptar los términos', () {
      final viewModel = SignUpViewModel(auth);
      fillValidSignUp(viewModel);

      viewModel.setAcceptedTerms(value: false);
      expect(viewModel.canSubmit, isFalse);

      viewModel.setAcceptedTerms(value: true);
      expect(viewModel.canSubmit, isTrue);
    });

    test('RF-AUT-05 · escribir no valida; perder el foco sí', () {
      final viewModel = SignUpViewModel(auth)..setEmail('esto-no-es-un-correo');
      expect(viewModel.emailError, isNull);

      viewModel.validateEmail();
      expect(viewModel.emailError, ValidationError.email);
    });

    test('corregir el campo retira el error sin esperar a perder el foco', () {
      final viewModel = SignUpViewModel(auth)
        ..setEmail('malo')
        ..validateEmail();
      expect(viewModel.emailError, isNotNull);

      viewModel.setEmail('criador@ejemplo.do');
      expect(viewModel.emailError, isNull);
    });

    test('no llama al backend si algún campo es inválido', () async {
      final viewModel = SignUpViewModel(auth);
      fillValidSignUp(viewModel);
      viewModel.setPasswordConfirmation('otra-cosa');

      expect(await viewModel.submit(locale: 'es'), isNull);
      expect(auth.signUpCalls, 0);
      expect(viewModel.passwordConfirmationError, ValidationError.passwordMismatch);
    });

    test('el alta correcta devuelve el correo normalizado', () async {
      final viewModel = SignUpViewModel(auth);
      fillValidSignUp(viewModel);
      viewModel.setEmail('  Criador@Ejemplo.DO ');

      expect(await viewModel.submit(locale: 'es'), 'criador@ejemplo.do');
      expect(auth.signUpCalls, 1);
      expect(auth.lastFullName, 'Ramón Peña');
      expect(auth.lastCountry, Country.dominicanRepublic);
    });

    test('el perfil guarda el idioma en el que se está usando la app', () async {
      final viewModel = SignUpViewModel(auth);
      fillValidSignUp(viewModel);

      await viewModel.submit(locale: 'en');
      expect(auth.lastLocale, 'en');
    });

    test('un fallo del backend deja el error y no devuelve correo', () async {
      auth.failure = const AuthFailure(reason: AuthFailureReason.emailAlreadyRegistered);
      final viewModel = SignUpViewModel(auth);
      fillValidSignUp(viewModel);

      expect(await viewModel.submit(locale: 'es'), isNull);
      expect(viewModel.failure, isA<AuthFailure>());
    });

    test('RV-02 · el medidor informa pero no bloquea el envío', () async {
      final viewModel = SignUpViewModel(auth);
      fillValidSignUp(viewModel);
      // Cumple el mínimo legal pero el medidor la califica floja.
      viewModel
        ..setPassword('gallera1')
        ..setPasswordConfirmation('gallera1');

      expect(viewModel.passwordStrength, PasswordStrength.weak);
      expect(await viewModel.submit(locale: 'es'), isNotNull);
    });
  });

  group('LoginViewModel', () {
    test('E-AUTH-01 · el fallo llega como credenciales inválidas', () async {
      auth.failure = const AuthFailure(reason: AuthFailureReason.invalidCredentials);
      final viewModel = LoginViewModel(auth: auth, preferences: preferences)
        ..setEmail('criador@ejemplo.do')
        ..setPassword('lo-que-sea');

      expect(await viewModel.submit(), isFalse);
      expect((viewModel.failure! as AuthFailure).reason, AuthFailureReason.invalidCredentials);
    });

    test('no valida el formato de la contraseña al entrar, solo que exista', () {
      final viewModel = LoginViewModel(auth: auth, preferences: preferences)
        // Una cuenta antigua puede no cumplir `RV-02`.
        ..setPassword('corta')
        ..validatePassword();

      expect(viewModel.passwordError, isNull);
    });

    test('«recordarme» guarda el correo normalizado y lo restaura', () async {
      final viewModel = LoginViewModel(auth: auth, preferences: preferences)
        ..setEmail('  Criador@Ejemplo.DO ')
        ..setPassword('gallera1')
        ..setRememberMe(value: true);

      expect(await viewModel.submit(), isTrue);
      expect(preferences.rememberedEmail, 'criador@ejemplo.do');

      final next = LoginViewModel(auth: auth, preferences: preferences);
      expect(next.initialEmail, 'criador@ejemplo.do');
      expect(next.rememberMe, isTrue);
    });

    test('sin «recordarme» se olvida el correo guardado', () async {
      await preferences.rememberEmail('viejo@ejemplo.do');

      final viewModel = LoginViewModel(auth: auth, preferences: preferences)
        ..setEmail('criador@ejemplo.do')
        ..setPassword('gallera1')
        ..setRememberMe(value: false);

      await viewModel.submit();
      expect(preferences.rememberedEmail, isNull);
    });
  });

  group('VerifyCodeViewModel', () {
    VerifyCodeViewModel build() => VerifyCodeViewModel(
      auth: auth,
      email: 'criador@ejemplo.do',
      purpose: VerificationPurpose.signUp,
    );

    test('RV-04 · un código incompleto no llega al backend', () async {
      final viewModel = build()..setCode('123');

      expect(await viewModel.verify(), isFalse);
      expect(auth.verifyCalls, 0);
      expect(viewModel.codeError, ValidationError.codeIncomplete);

      viewModel.dispose();
    });

    test('verifica con el propósito de la pantalla', () async {
      final viewModel = build()..setCode('123456');

      expect(await viewModel.verify(), isTrue);
      expect(auth.lastPurpose, VerificationPurpose.signUp);
      expect(auth.lastCode, '123456');

      viewModel.dispose();
    });

    test('RF-AUT-08 · el reenvío espera la cuenta regresiva de 60 s', () {
      fakeAsync((async) {
        final viewModel = build();

        expect(viewModel.secondsLeft, AppConfig.resendCodeCooldown.inSeconds);
        expect(viewModel.canResend, isFalse);

        async.elapse(AppConfig.resendCodeCooldown - const Duration(seconds: 1));
        expect(viewModel.canResend, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(viewModel.secondsLeft, 0);
        expect(viewModel.canResend, isTrue);

        viewModel.dispose();
      });
    });

    test('un código vencido habilita el reenvío de inmediato (CU-01 alterno B)', () {
      fakeAsync((async) {
        auth.failure = const AuthFailure(reason: AuthFailureReason.codeExpired);
        final viewModel = build()..setCode('123456');

        expect(viewModel.canResend, isFalse);
        viewModel.verify();
        async.flushMicrotasks();

        expect(viewModel.secondsLeft, 0);
        expect(viewModel.canResend, isTrue);

        viewModel.dispose();
      });
    });

    test('reenviar vuelve a arrancar la cuenta regresiva', () {
      fakeAsync((async) {
        final viewModel = build();
        async.elapse(AppConfig.resendCodeCooldown);
        expect(viewModel.canResend, isTrue);

        viewModel.resend();
        async.flushMicrotasks();

        expect(auth.resendCalls, 1);
        expect(viewModel.secondsLeft, AppConfig.resendCodeCooldown.inSeconds);

        viewModel.dispose();
      });
    });
  });

  group('ForgotPasswordViewModel · RF-AUT-12', () {
    test('envía el código y devuelve el correo normalizado', () async {
      final viewModel = ForgotPasswordViewModel(auth)..setEmail(' Criador@Ejemplo.DO ');

      expect(await viewModel.submit(), 'criador@ejemplo.do');
      expect(auth.sendResetCalls, 1);
    });

    test('un correo inválido no llega al backend', () async {
      final viewModel = ForgotPasswordViewModel(auth)..setEmail('nope');

      expect(await viewModel.submit(), isNull);
      expect(auth.sendResetCalls, 0);
    });
  });

  group('NewPasswordViewModel · RF-AUT-13', () {
    test('cierra la sesión de recuperación después de guardar', () async {
      final viewModel = NewPasswordViewModel(auth)
        ..setPassword('gallera1')
        ..setConfirmation('gallera1');

      expect(await viewModel.submit(), isTrue);
      expect(auth.callOrder, ['updatePassword', 'signOut']);
    });

    test('RV-03 · la confirmación distinta no llega al backend', () async {
      final viewModel = NewPasswordViewModel(auth)
        ..setPassword('gallera1')
        ..setConfirmation('gallera2');

      expect(await viewModel.submit(), isFalse);
      expect(auth.updatePasswordCalls, 0);
      expect(viewModel.confirmationError, ValidationError.passwordMismatch);
    });

    test('si falla el guardado no se cierra la sesión', () async {
      auth.failure = const AuthFailure(reason: AuthFailureReason.samePassword);
      final viewModel = NewPasswordViewModel(auth)
        ..setPassword('gallera1')
        ..setConfirmation('gallera1');

      expect(await viewModel.submit(), isFalse);
      expect(auth.signOutCalls, 0);
    });
  });
}
