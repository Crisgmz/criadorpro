import '../../../core/base/base_viewmodel.dart';
import '../../../core/domain/sex.dart';
import '../model/bird.dart';
import '../repository/birds_repository.dart';

/// Selector de progenitor — pantalla 18, `RF-REG-11`.
///
/// Existe porque un desplegable deja de servir en cuanto el criadero pasa de
/// veinte ejemplares: hay que poder buscar. Y porque el progenitor que falta
/// suele ser justo el que no está registrado, así que desde aquí se puede dar
/// de alta sin perder lo que ya se había capturado en el formulario anterior.
class ParentPickerViewModel extends BaseViewModel {
  ParentPickerViewModel({
    required BirdsRepository repository,
    required String ownerId,
    required Sex sex,
    String? excludeId,
  }) : _repository = repository,
       _ownerId = ownerId,
       _sex = sex,
       _excludeId = excludeId;

  final BirdsRepository _repository;
  final String _ownerId;
  final Sex _sex;
  final String? _excludeId;

  String _search = '';
  List<Bird> _candidates = const [];

  Sex get sex => _sex;
  String get search => _search;
  List<Bird> get candidates => _candidates;

  /// `true` cuando no hay resultados **porque se está buscando**. El estado
  /// vacío de una búsqueda dice algo distinto al de un criadero sin ejemplares
  /// de ese sexo, y ofrecer «crear» en ambos casos confundiría.
  bool get isFilteredEmpty => _candidates.isEmpty && _search.trim().isNotEmpty;

  Future<void> load() async {
    setLoading();
    await _query();
    setReady();
  }

  Future<void> setSearch(String value) async {
    _search = value;
    await _query();
    safeNotify();
  }

  Future<void> _query() async {
    final result = await _repository.parentCandidates(
      ownerId: _ownerId,
      sex: _sex,
      excludeId: _excludeId,
      search: _search,
    );
    _candidates = result.valueOrNull ?? const [];
  }

  /// Tras dar de alta un ejemplar desde aquí: se relee la lista para que el
  /// recién creado aparezca. Se limpia la búsqueda porque el nombre nuevo casi
  /// nunca coincide con lo que se estaba tecleando.
  Future<void> refreshAfterCreate() async {
    _search = '';
    await _query();
    safeNotify();
  }
}
