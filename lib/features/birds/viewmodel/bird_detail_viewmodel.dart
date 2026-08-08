import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/error/failure.dart';
import '../model/bird.dart';
import '../repository/birds_repository.dart';

/// Ficha de un ejemplar, con sus progenitores ya resueltos a nombres.
class BirdDetailViewModel extends BaseViewModel {
  BirdDetailViewModel({required BirdsRepository repository, required String birdId})
    : _repository = repository,
      _birdId = birdId {
    _subscribe();
  }

  final BirdsRepository _repository;
  final String _birdId;

  StreamSubscription<Bird?>? _subscription;

  Bird? _bird;
  Bird? _father;
  Bird? _mother;

  Bird? get bird => _bird;
  Bird? get father => _father;
  Bird? get mother => _mother;

  Future<bool> delete() async {
    final result = await _repository.delete(_birdId);
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
    _subscription = _repository.watchBird(_birdId).listen(
      (bird) async {
        _bird = bird;
        if (bird == null || bird.isDeleted) {
          setFailure(const NotFoundFailure(debugMessage: 'bird eliminado o inexistente'));
          return;
        }
        await _resolveParents(bird);
        setReady();
      },
      onError: (Object error) =>
          setFailure(DatabaseFailure(debugMessage: error.toString(), cause: error)),
    );
  }

  Future<void> _resolveParents(Bird bird) async {
    _father = await _findOrNull(bird.fatherId);
    _mother = await _findOrNull(bird.motherId);
  }

  Future<Bird?> _findOrNull(String? id) async {
    if (id == null) return null;
    final result = await _repository.findById(id);
    return result.valueOrNull;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
