import '../../../core/base/base_viewmodel.dart';
import '../../../core/domain/markings.dart';
import '../../../core/domain/sex.dart';
import '../../../core/media/photo_service.dart';
import '../../../core/utils/validators.dart';
import '../model/bird.dart';
import '../repository/birds_repository.dart';

/// Alta y edición de un ejemplar — pantalla 19.
///
/// Mantiene el borrador en memoria y solo toca el repositorio al enviar, así el
/// usuario puede cambiar de idea sin dejar registros a medias.
class BirdFormViewModel extends BaseViewModel {
  BirdFormViewModel({
    required BirdsRepository repository,
    required PhotoService photoService,
    required String ownerId,
    String? birdId,
  }) : _repository = repository,
       _photoService = photoService,
       _ownerId = ownerId,
       _birdId = birdId;

  final BirdsRepository _repository;
  final PhotoService _photoService;
  final String _ownerId;
  final String? _birdId;

  Bird? _original;

  String _plate = '';
  String _name = '';
  Sex _sex = Sex.unknown;
  BirdStatus _status = BirdStatus.active;
  DateTime? _birthDate;
  String _color = '';
  String? _birthMark;
  WingBand? _wingLeft;
  WingBand? _wingRight;
  String _line = '';
  String _weight = '';
  String _notes = '';
  Bird? _father;
  Bird? _mother;
  String? _photoPath;
  bool _capturingPhoto = false;

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

  /// Marca de nacimiento — `1,4` o `none`.
  String? get birthMark => _birthMark;

  WingBand? get wingLeft => _wingLeft;
  WingBand? get wingRight => _wingRight;
  String get line => _line;
  String get weight => _weight;
  String get notes => _notes;
  Bird? get father => _father;
  Bird? get mother => _mother;

  /// Se derivan del ejemplar elegido: así no pueden quedar desincronizados el
  /// id que se guarda y el nombre que se muestra.
  String? get fatherId => _father?.id;
  String? get motherId => _mother?.id;

  /// El propio ejemplar no puede ser su padre ni su madre (`RV-10`).
  String? get excludeId => _birdId;

  /// Ruta local de la foto — `RF-REG-15`.
  String? get photoPath => _photoPath;

  /// La captura pasa por la cámara y por una recompresión: puede tardar lo
  /// suficiente como para que haga falta decírselo al usuario.
  bool get isCapturingPhoto => _capturingPhoto;
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
      _birthMark = bird.birthMark;
      _wingLeft = WingBand.fromId(bird.wingBandLeft);
      _wingRight = WingBand.fromId(bird.wingBandRight);
      _line = bird.line ?? '';
      _weight = bird.weightG?.toString() ?? '';
      _notes = bird.notes ?? '';
      _photoPath = bird.photoPath;
      _father = await _findOrNull(bird.fatherId);
      _mother = await _findOrNull(bird.motherId);
    } else {
      _plate = (await _repository.nextPlate(_ownerId)).toString();
    }

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

  void setBirthMark(String? value) {
    _birthMark = value;
    safeNotify();
  }

  void setWingLeft(WingBand? value) {
    _wingLeft = value;
    safeNotify();
  }

  void setWingRight(WingBand? value) {
    _wingRight = value;
    safeNotify();
  }

  void setLine(String value) => _line = value;

  void setWeight(String value) {
    _weight = value;
    _weightOutOfRange = false;
    if (_weightError != null) _weightError = null;
    safeNotify();
  }

  void setNotes(String value) => _notes = value;

  /// `RF-REG-15` — cámara o galería. Cancelar no cambia nada ni avisa.
  Future<void> capturePhoto(PhotoSource source) async {
    _capturingPhoto = true;
    safeNotify();

    final path = await _photoService.capture(source);
    if (path != null) {
      // La anterior se borra solo cuando la nueva ya está en disco: si la
      // captura falla, el ejemplar conserva la foto que tenía.
      final previous = _photoPath;
      _photoPath = path;
      if (previous != null && previous != path) await _photoService.deleteFile(previous);
    }

    _capturingPhoto = false;
    safeNotify();
  }

  /// Quita la foto del ejemplar. El archivo no se borra hasta guardar: si el
  /// criador se arrepiente y sale sin guardar, la foto sigue ahí.
  void removePhoto() {
    _photoPath = null;
    safeNotify();
  }

  /// Lo elige la pantalla 18 (`RF-REG-11`).
  void setFather(Bird? value) {
    _father = value;
    safeNotify();
  }

  void setMother(Bird? value) {
    _mother = value;
    safeNotify();
  }

  Future<Bird?> _findOrNull(String? id) async {
    if (id == null) return null;
    final result = await _repository.findById(id);
    return result.valueOrNull;
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
      birthMark: () => _birthMark,
      wingBandLeft: () => _wingLeft?.id,
      wingBandRight: () => _wingRight?.id,
      line: () => _emptyToNull(_line),
      weightG: _parsedWeight,
      fatherId: () => fatherId,
      motherId: () => motherId,
      notes: () => _emptyToNull(_notes),
      photoPath: () => _photoPath,
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
