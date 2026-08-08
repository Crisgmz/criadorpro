import '../../../core/base/base_viewmodel.dart';
import '../../../core/domain/sex.dart';
import '../../../core/utils/validators.dart';
import '../model/bird.dart';
import '../repository/birds_repository.dart';

/// Alta y edición de un ejemplar — pantalla 19.
///
/// Mantiene el borrador en memoria y solo toca el repositorio al enviar, así el
/// usuario puede cambiar de idea sin dejar registros a medias.
class BirdFormViewModel extends BaseViewModel {
  BirdFormViewModel({required BirdsRepository repository, required String ownerId, String? birdId})
    : _repository = repository,
      _ownerId = ownerId,
      _birdId = birdId;

  final BirdsRepository _repository;
  final String _ownerId;
  final String? _birdId;

  Bird? _original;

  String _plate = '';
  String _name = '';
  Sex _sex = Sex.unknown;
  BirdStatus _status = BirdStatus.active;
  DateTime? _birthDate;
  String _color = '';
  String _line = '';
  String _weight = '';
  String _notes = '';
  String? _fatherId;
  String? _motherId;

  List<Bird> _fatherCandidates = const [];
  List<Bird> _motherCandidates = const [];

  ValidationError? _plateError;
  ValidationError? _weightError;
  bool _plateTaken = false;
  bool _weightOutOfRange = false;

  bool get isEditing => _birdId != null;
  String get plate => _plate;
  String get name => _name;
  Sex get sex => _sex;
  BirdStatus get status => _status;
  DateTime? get birthDate => _birthDate;
  String get color => _color;
  String get line => _line;
  String get weight => _weight;
  String get notes => _notes;
  String? get fatherId => _fatherId;
  String? get motherId => _motherId;
  List<Bird> get fatherCandidates => _fatherCandidates;
  List<Bird> get motherCandidates => _motherCandidates;
  ValidationError? get plateError => _plateError;
  ValidationError? get weightError => _weightError;

  /// `RV-08` — la placa ya existe. Es advertencia, no bloqueo: el libro de
  /// papel a veces repite y el criador necesita poder reflejarlo.
  bool get isPlateTaken => _plateTaken;

  /// `RV-12` — peso fuera de 100–8000 g. También advierte y deja guardar.
  bool get isWeightOutOfRange => _weightOutOfRange;

  /// Carga el ejemplar a editar (si lo hay) y los posibles progenitores.
  ///
  /// En un alta propone la placa siguiente del criadero, que es lo que hace que
  /// registrar sea más rápido que escribir a mano: casi siempre es la correcta.
  Future<void> load() async {
    setLoading();

    if (_birdId != null) {
      final result = await _repository.findById(_birdId);
      final bird = result.valueOrNull;
      if (bird == null) {
        setFailure(result.failureOrNull!);
        return;
      }
      _original = bird;
      _plate = bird.plate.toString();
      _name = bird.name ?? '';
      _sex = bird.sex;
      _status = bird.status;
      _birthDate = bird.birthDate;
      _color = bird.color ?? '';
      _line = bird.line ?? '';
      _weight = bird.weightG?.toString() ?? '';
      _notes = bird.notes ?? '';
      _fatherId = bird.fatherId;
      _motherId = bird.motherId;
    } else {
      _plate = (await _repository.nextPlate(_ownerId)).toString();
    }

    final fathers = await _repository.parentCandidates(
      ownerId: _ownerId,
      sex: Sex.male,
      excludeId: _birdId,
    );
    final mothers = await _repository.parentCandidates(
      ownerId: _ownerId,
      sex: Sex.female,
      excludeId: _birdId,
    );
    _fatherCandidates = fathers.valueOrNull ?? const [];
    _motherCandidates = mothers.valueOrNull ?? const [];

    setReady();
  }

  void setPlate(String value) {
    _plate = value;
    _plateTaken = false;
    if (_plateError != null) _plateError = null;
    safeNotify();
  }

  void setName(String value) => _name = value;

  void setSex(Sex value) {
    if (_sex == value) return;
    _sex = value;
    safeNotify();
  }

  void setStatus(BirdStatus value) {
    if (_status == value) return;
    _status = value;
    safeNotify();
  }

  void setBirthDate(DateTime? value) {
    _birthDate = value;
    safeNotify();
  }

  void setColor(String value) => _color = value;

  void setLine(String value) => _line = value;

  void setWeight(String value) {
    _weight = value;
    _weightOutOfRange = false;
    if (_weightError != null) _weightError = null;
    safeNotify();
  }

  void setNotes(String value) => _notes = value;

  void setFatherId(String? value) {
    _fatherId = value;
    safeNotify();
  }

  void setMotherId(String? value) {
    _motherId = value;
    safeNotify();
  }

  // --- Validación al perder el foco (RF-AUT-05) ---------------------------

  Future<void> validatePlate() async {
    _plateError = Validators.plate(_plate);
    _plateTaken = false;

    if (_plateError == null) {
      _plateTaken = await _repository.isPlateTaken(
        ownerId: _ownerId,
        plate: int.parse(_plate.trim()),
        excludeId: _birdId,
      );
    }
    safeNotify();
  }

  void validateWeight() {
    _weightError = Validators.optionalNumber(_weight);
    _weightOutOfRange = _weightError == null && _parsedWeight() != null
        ? !Validators.isWeightInRange(_parsedWeight()!)
        : false;
    safeNotify();
  }

  /// Devuelve el ejemplar guardado, o `null` si no se pudo guardar. La View
  /// decide entonces si cierra la pantalla o muestra el error.
  Future<Bird?> submit() async {
    _plateError = Validators.plate(_plate);
    _weightError = Validators.optionalNumber(_weight);
    if (_plateError != null || _weightError != null) {
      safeNotify();
      return null;
    }

    setLoading();
    final now = DateTime.now();
    final base = _original ?? Bird.draft(ownerId: _ownerId, now: now);
    final draft = base.copyWith(
      plate: int.parse(_plate.trim()),
      sex: _sex,
      status: _status,
      name: () => _emptyToNull(_name),
      birthDate: () => _birthDate,
      color: () => _emptyToNull(_color),
      line: () => _emptyToNull(_line),
      weightG: _parsedWeight,
      fatherId: () => _fatherId,
      motherId: () => _motherId,
      notes: () => _emptyToNull(_notes),
    );

    final result = await _repository.save(draft);
    return result.fold(
      ok: (bird) {
        setReady();
        return bird;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }

  int? _parsedWeight() {
    final trimmed = _weight.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'))?.round();
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
