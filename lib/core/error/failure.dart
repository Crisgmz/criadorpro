/// Errores de dominio. Los repositorios nunca lanzan excepciones hacia arriba:
/// las traducen a un [Failure] y lo devuelven dentro de un `Err`.
///
/// El texto que ve el usuario NO vive aquí — se resuelve en la capa de View con
/// `failureMessage()` (ver `failure_messages.dart`), para que el ViewModel siga
/// sin depender de Flutter ni de las traducciones.
sealed class Failure {
  const Failure({this.debugMessage, this.cause});

  /// Detalle técnico para logs. Nunca se muestra al usuario.
  final String? debugMessage;
  final Object? cause;

  @override
  String toString() => '$runtimeType(${debugMessage ?? ''})';
}

/// No hay conexión, o la petición al backend falló por red.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.debugMessage, super.cause});
}

/// Error de la base local (Drift/SQLite).
final class DatabaseFailure extends Failure {
  const DatabaseFailure({super.debugMessage, super.cause});
}

/// Credenciales inválidas, sesión expirada o usuario no autenticado.
final class AuthFailure extends Failure {
  const AuthFailure({this.reason = AuthFailureReason.unknown, super.debugMessage, super.cause});

  final AuthFailureReason reason;
}

enum AuthFailureReason {
  /// `E-AUTH-01` — mensaje único: nunca revela si el correo está registrado.
  invalidCredentials,
  emailAlreadyRegistered,
  notAuthenticated,
  notConfigured,

  /// `E-AUTH-02` — el código venció o agotó sus intentos.
  codeExpired,

  /// El código no coincide. Se trata igual que el vencido: reenvío inmediato.
  codeInvalid,

  /// `E-AUTH-03` — demasiados intentos en la ventana de tiempo (`RNF-18`).
  tooManyAttempts,

  /// La contraseña nueva es la misma que la anterior.
  samePassword,

  /// Acceso con Google o Apple todavía sin credenciales de plataforma.
  providerUnavailable,

  unknown,
}

/// El recurso pedido no existe (o fue borrado).
final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.debugMessage});
}

/// Un campo del formulario no pasó la validación.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.field, {super.debugMessage});

  /// Nombre lógico del campo, p. ej. `name`, `email`.
  final String field;
}

/// El plan actual no permite crear más registros de este tipo.
final class PlanLimitFailure extends Failure {
  const PlanLimitFailure({required this.limit, required this.current, super.debugMessage});

  final int limit;
  final int current;
}

/// Cualquier otra cosa. Siempre con `debugMessage` para poder diagnosticarla.
final class UnknownFailure extends Failure {
  const UnknownFailure({super.debugMessage, super.cause});
}
