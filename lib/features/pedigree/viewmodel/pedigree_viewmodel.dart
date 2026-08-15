import '../../../core/base/base_viewmodel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../model/pedigree_node.dart';
import '../repository/pedigree_repository.dart';

/// Pantalla 23 — árbol genealógico, `RF-PED-01` a `RF-PED-07`.
class PedigreeViewModel extends BaseViewModel {
  PedigreeViewModel({
    required PedigreeRepository repository,
    required ProfilesDao profilesDao,
    required String ownerId,
    required String birdId,
  }) : _repository = repository,
       _profilesDao = profilesDao,
       _ownerId = ownerId,
       _birdId = birdId;

  final PedigreeRepository _repository;
  final ProfilesDao _profilesDao;
  final String _ownerId;
  final String _birdId;

  /// Profundidades ofrecidas — `RF-PED-02`.
  static const List<int> depthOptions = [2, 3, 4];

  int _depth = 4;
  int _allowedDepth = PedigreeRepository.maxDepth;
  PedigreeNode? _root;

  PedigreeNode? get root => _root;

  /// Generaciones que se están mostrando.
  int get depth => _depth;

  /// Tope que impone el plan — `RF-PED-03`. Gratis llega a dos.
  int get allowedDepth => _allowedDepth;

  /// `true` cuando el plan está recortando el árbol. La pantalla lo dice y
  /// ofrece cómo ampliarlo: quedarse callado haría pensar que al ejemplar le
  /// faltan ancestros, que es justo lo contrario de lo que pasa.
  bool get isLimitedByPlan => _allowedDepth < PedigreeRepository.maxDepth;

  bool isDepthAvailable(int value) => value <= _allowedDepth;

  Future<void> load() async {
    setLoading();

    final profile = await _profilesDao.findById(_ownerId);
    _allowedDepth = SubscriptionPlan.fromId(profile?.plan).pedigreeDepth;
    // Sin plan de pago se arranca ya en el máximo permitido, no en cuatro: el
    // selector no debe ofrecer una vista que luego se recorta.
    _depth = _depth.clamp(1, _allowedDepth);

    await _build();
  }

  Future<void> setDepth(int value) async {
    if (!isDepthAvailable(value) || value == _depth) return;
    _depth = value;
    setLoading();
    await _build();
  }

  Future<void> _build() async {
    final result = await _repository.build(rootId: _birdId, depth: _depth);
    result.fold(
      ok: (node) {
        _root = node;
        setReady();
      },
      err: setFailure,
    );
  }
}
