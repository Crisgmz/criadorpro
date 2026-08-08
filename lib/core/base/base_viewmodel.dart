import 'package:flutter/foundation.dart';

import '../error/failure.dart';
import 'view_state.dart';

/// Base de todos los ViewModels.
///
/// Deliberadamente depende de `foundation`, no de `material`: un ViewModel no
/// navega, no muestra diálogos y no conoce widgets. Expone estado y comandos;
/// la View reacciona.
abstract class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  Failure? _failure;
  bool _disposed = false;

  ViewState get state => _state;
  Failure? get failure => _failure;

  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  bool get isDisposed => _disposed;

  @protected
  void setLoading() {
    _failure = null;
    _moveTo(ViewState.loading);
  }

  @protected
  void setReady() {
    _failure = null;
    _moveTo(ViewState.ready);
  }

  @protected
  void setFailure(Failure failure) {
    _failure = failure;
    _moveTo(ViewState.error);
  }

  /// Limpia el error sin tocar los datos ya cargados. Útil tras mostrar un
  /// snackbar, para que no vuelva a dispararse en el siguiente rebuild.
  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    if (_state == ViewState.error) _state = ViewState.ready;
    safeNotify();
  }

  void _moveTo(ViewState next) {
    _state = next;
    safeNotify();
  }

  /// `notifyListeners` seguro: los comandos son asíncronos y pueden terminar
  /// después de que la View se haya destruido.
  @protected
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
