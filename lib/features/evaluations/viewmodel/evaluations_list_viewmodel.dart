import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/error/failure.dart';
import '../model/evaluation.dart';
import '../repository/evaluations_repository.dart';

/// Historial de pruebas del criadero — pantalla 24, `RF-PRU-03` y `RF-PRU-04`.
class EvaluationsListViewModel extends BaseViewModel {
  EvaluationsListViewModel({required EvaluationsRepository repository, required String ownerId})
    : _repository = repository,
      _ownerId = ownerId {
    _subscribe();
  }

  final EvaluationsRepository _repository;
  final String _ownerId;

  StreamSubscription<List<Evaluation>>? _subscription;
  StreamSubscription<EvaluationStats>? _statsSubscription;

  List<Evaluation> _evaluations = const [];
  EvaluationStats _stats = EvaluationStats.empty;
  EvaluationResult? _filter;
  bool _isAvailable = true;

  List<Evaluation> get evaluations => _evaluations;
  EvaluationStats get stats => _stats;
  EvaluationResult? get filter => _filter;

  /// `RF-PRU-06` — el módulo es de Pro en adelante. La pantalla **no se
  /// oculta**: se muestra con su aviso, porque esconderla dejaría al criador
  /// sin saber que existe.
  bool get isAvailable => _isAvailable;

  Future<void> load() async {
    _isAvailable = await _repository.isAvailableFor(_ownerId);
    safeNotify();
  }

  void setFilter(EvaluationResult? value) {
    if (_filter == value) return;
    _filter = value;
    _subscription?.cancel();
    _subscribeToList();
    safeNotify();
  }

  Future<bool> delete(String id) async {
    final result = await _repository.delete(id);
    return result.fold(
      ok: (_) => true,
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  void _subscribe() {
    setLoading();
    _subscribeToList();

    // Las estadísticas van por su cuenta y **sin filtrar**: `RF-PRU-03` pide
    // el resumen del criadero, no el del filtro que esté puesto.
    _statsSubscription = _repository.watchStats(_ownerId).listen((stats) {
      _stats = stats;
      safeNotify();
    }, onError: (Object _) {});
  }

  void _subscribeToList() {
    _subscription = _repository.watchAll(ownerId: _ownerId, result: _filter).listen(
      (evaluations) {
        _evaluations = evaluations;
        setReady();
      },
      onError: (Object error) =>
          setFailure(DatabaseFailure(debugMessage: error.toString(), cause: error)),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }
}
