import '../../l10n/generated/app_l10n.dart';
import '../config/app_config.dart';
import '../utils/validators.dart';
import 'failure.dart';

/// Traduce el error de dominio al idioma del usuario.
///
/// Vive en la capa de View a propósito: los [Failure] no llevan texto, así el
/// ViewModel no necesita conocer las traducciones.
String failureMessage(AppL10n l10n, Failure failure) => switch (failure) {
  NetworkFailure() => l10n.errorNetwork,
  DatabaseFailure() => l10n.errorDatabase,
  NotFoundFailure() => l10n.errorNotFound,
  ValidationFailure() => l10n.errorValidation,
  PlanLimitFailure(:final limit, :final current) => l10n.errorPlanLimit(limit, current),
  AuthFailure(:final reason) => switch (reason) {
    AuthFailureReason.invalidCredentials => l10n.errorAuthInvalidCredentials,
    AuthFailureReason.emailAlreadyRegistered => l10n.errorAuthEmailTaken,
    AuthFailureReason.notAuthenticated => l10n.errorAuthNotAuthenticated,
    AuthFailureReason.notConfigured => l10n.errorAuthNotConfigured,
    AuthFailureReason.codeExpired => l10n.errorAuthCodeExpired,
    AuthFailureReason.codeInvalid => l10n.errorAuthCodeInvalid,
    AuthFailureReason.tooManyAttempts => l10n.errorAuthTooManyAttempts,
    AuthFailureReason.samePassword => l10n.errorAuthSamePassword,
    AuthFailureReason.providerUnavailable => l10n.errorAuthProviderUnavailable,
    AuthFailureReason.unknown => l10n.errorUnknown,
  },
  UnknownFailure() => l10n.errorUnknown,
};

/// Traduce el error de un campo de formulario.
String validationMessage(AppL10n l10n, ValidationError error) => switch (error) {
  ValidationError.required => l10n.validationRequired,
  ValidationError.email => l10n.validationEmail,
  ValidationError.emailTooLong => l10n.validationEmailTooLong,
  ValidationError.passwordTooShort => l10n.validationPasswordShort(AppConfig.minPasswordLength),
  ValidationError.passwordNeedsLetterAndNumber => l10n.validationPasswordNeedsLetterAndNumber,
  ValidationError.passwordMismatch => l10n.validationPasswordMismatch,
  ValidationError.nameLength => l10n.validationNameLength,
  ValidationError.farmNameLength => l10n.validationFarmNameLength,
  ValidationError.plateOutOfRange => l10n.validationPlateRange(Validators.maxInitialPlate),
  ValidationError.codeIncomplete => l10n.validationCodeIncomplete,
  ValidationError.phoneInvalid => l10n.validationPhone,
  ValidationError.notANumber => l10n.validationNumber,
};
