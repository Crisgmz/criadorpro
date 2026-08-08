import '../error/failure.dart';

/// Resultado explícito de una operación de repositorio: `Ok` con el valor o
/// `Err` con un [Failure]. Evita que las excepciones crucen la capa de datos.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// El valor si fue `Ok`, `null` si fue `Err`.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// El fallo si fue `Err`, `null` si fue `Ok`.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Colapsa ambos casos en un único valor.
  R fold<R>({required R Function(T value) ok, required R Function(Failure failure) err}) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };

  /// Transforma el valor conservando el fallo.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok(transform(value)),
    Err<T>(:final failure) => Err(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}

/// Ejecuta [action] y envuelve cualquier excepción en [onError].
///
/// Atajo para repositorios: `return guard(() async => ..., (e, s) => DatabaseFailure(...))`.
Future<Result<T>> guard<T>(
  Future<T> Function() action,
  Failure Function(Object error, StackTrace stackTrace) onError,
) async {
  try {
    return Ok(await action());
  } catch (error, stackTrace) {
    return Err(onError(error, stackTrace));
  }
}
