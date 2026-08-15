import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/error/failure.dart';
import '../model/bird.dart';
import '../model/clutch.dart';
import '../repository/birds_repository.dart';
import '../repository/clutches_repository.dart';

/// Un bloque de la pestaña Descendencia — `RF-REG-13`.
///
/// Las crías se agrupan por camada porque así las piensa el criador: «los ocho
/// del cruce de marzo», no ocho ejemplares sueltos. Las que se registraron a
/// mano, sin pasar por el registro de cruce, no tienen camada y caen en un
/// grupo sin encabezado — existir, existen igual.
class OffspringGroup {
  const OffspringGroup({required this.chicks, this.clutch});

  /// `null` para las crías registradas una a una.
  final Clutch? clutch;
  final List<Bird> chicks;
}

/// Ficha de un ejemplar — pantallas 20 a 22, `RF-REG-12` y `RF-REG-13`.
class BirdDetailViewModel extends BaseViewModel {
  BirdDetailViewModel({
    required BirdsRepository repository,
    required ClutchesRepository clutchesRepository,
    required String birdId,
  }) : _repository = repository,
       _clutchesRepository = clutchesRepository,
       _birdId = birdId {
    _subscribe();
  }

  final BirdsRepository _repository;
  final ClutchesRepository _clutchesRepository;
  final String _birdId;

  StreamSubscription<Bird?>? _subscription;
  StreamSubscription<List<Bird>>? _childrenSubscription;

  Bird? _bird;
  Bird? _father;
  Bird? _mother;
  List<OffspringGroup> _offspring = const [];

  Bird? get bird => _bird;
  Bird? get father => _father;
  Bird? get mother => _mother;

  /// Descendencia ya agrupada, con las camadas más recientes primero.
  List<OffspringGroup> get offspring => _offspring;

  int get offspringCount => _offspring.fold(0, (total, group) => total + group.chicks.length);

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

    // En su propia suscripción: registrar una camada nueva debe refrescar la
    // pestaña sin que haga falta salir de la ficha y volver a entrar.
    _childrenSubscription = _repository.watchChildren(_birdId).listen((children) async {
      _offspring = await _groupByClutch(children);
      safeNotify();
    }, onError: (Object _) {});
  }

  /// Agrupa por camada y ordena por fecha, lo más reciente arriba. Las crías
  /// sin camada van al final: son la excepción, no lo que el criador busca.
  Future<List<OffspringGroup>> _groupByClutch(List<Bird> children) async {
    if (children.isEmpty) return const [];

    final byClutch = <String, List<Bird>>{};
    final loose = <Bird>[];
    for (final child in children) {
      final id = child.clutchId;
      if (id == null) {
        loose.add(child);
      } else {
        byClutch.putIfAbsent(id, () => []).add(child);
      }
    }

    final clutches = await _clutchesRepository.findByIds(byClutch.keys);

    final groups = <OffspringGroup>[];
    for (final entry in byClutch.entries) {
      groups.add(OffspringGroup(clutch: clutches[entry.key], chicks: entry.value));
    }
    groups.sort((a, b) {
      final dateA = a.clutch?.date;
      final dateB = b.clutch?.date;
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });

    if (loose.isNotEmpty) groups.add(OffspringGroup(chicks: loose));
    return groups;
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
    _childrenSubscription?.cancel();
    super.dispose();
  }
}
