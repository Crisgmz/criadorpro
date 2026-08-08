import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure.dart';
import '../model/bird.dart';
import '../repository/birds_repository.dart';

/// Lista de ejemplares con búsqueda y filtros — `RF-REG-03` a `RF-REG-05`.
///
/// Se apoya en un stream de Drift: cuando la sincronización trae cambios la
/// lista se actualiza sola, sin recargar a mano.
class BirdsListViewModel extends BaseViewModel {
  BirdsListViewModel({required BirdsRepository repository, required String ownerId})
    : _repository = repository,
      _ownerId = ownerId {
    _subscribe();
  }

  final BirdsRepository _repository;
  final String _ownerId;

  StreamSubscription<List<Bird>>? _subscription;
  Timer? _debounce;

  List<Bird> _birds = const [];
  String _search = '';
  Sex? _sexFilter;
  BirdStatus? _statusFilter;

  List<Bird> get birds => _birds;
  String get search => _search;
  Sex? get sexFilter => _sexFilter;
  BirdStatus? get statusFilter => _statusFilter;

  /// `true` cuando no hay resultados pero sí hay un filtro activo: la View
  /// muestra "sin resultados" en vez de "aún no hay ejemplares".
  bool get isFiltered => _search.trim().isNotEmpty || _sexFilter != null || _statusFilter != null;

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    safeNotify();
    // Teclear no debe reabrir la consulta en cada pulsación.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _subscribe);
  }

  void setSexFilter(Sex? sex) {
    if (_sexFilter == sex) return;
    _sexFilter = sex;
    safeNotify();
    _subscribe();
  }

  /// `RF-REG-05` — el estado filtra igual que el sexo. Sirve sobre todo para
  /// reencontrar lo que salió del criadero: un ejemplar vendido desaparece de
  /// la vista habitual pero nunca del libro.
  void setStatusFilter(BirdStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    safeNotify();
    _subscribe();
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
    _subscription?.cancel();
    if (_birds.isEmpty) setLoading();

    _subscription = _repository
        .watchBirds(ownerId: _ownerId, search: _search, sex: _sexFilter, status: _statusFilter)
        .listen(
          (birds) {
            _birds = birds;
            setReady();
          },
          onError: (Object error, StackTrace stackTrace) =>
              setFailure(DatabaseFailure(debugMessage: error.toString(), cause: error)),
        );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
