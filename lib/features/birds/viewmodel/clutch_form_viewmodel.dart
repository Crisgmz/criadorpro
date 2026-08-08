import '../../../core/base/base_viewmodel.dart';
import '../../../core/domain/sex.dart';
import '../model/bird.dart';
import '../model/clutch.dart';
import '../repository/birds_repository.dart';
import '../repository/clutches_repository.dart';

/// Registro de camada — pantalla 21, `RF-REG-08` a `RF-REG-11`.
///
/// La promesa es registrar ocho crías en menos de un minuto, así que el estado
/// arranca ya utilizable: fecha de hoy, una cría, y la placa siguiente del
/// criadero calculada. Solo la fecha y el número de crías son obligatorios; el
/// resto se puede completar después desde cada ficha.
class ClutchFormViewModel extends BaseViewModel {
  ClutchFormViewModel({
    required ClutchesRepository repository,
    required BirdsRepository birdsRepository,
    required String ownerId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _birdsRepository = birdsRepository,
       _ownerId = ownerId,
       _clock = clock;

  final ClutchesRepository _repository;
  final BirdsRepository _birdsRepository;
  final String _ownerId;
  final DateTime Function() _clock;

  DateTime _date = DateTime.now();
  int _hatched = 1;
  String _eggs = '';
  String? _fatherId;
  String? _motherId;
  String _line = '';
  String _notes = '';

  int _firstPlate = 1;
  List<Bird> _fatherCandidates = const [];
  List<Bird> _motherCandidates = const [];

  bool _dateInFuture = false;
  bool _hatchedOverEggs = false;

  DateTime get date => _date;
  int get hatched => _hatched;
  String get eggs => _eggs;
  String? get fatherId => _fatherId;
  String? get motherId => _motherId;
  String get line => _line;
  String get notes => _notes;
  List<Bird> get fatherCandidates => _fatherCandidates;
  List<Bird> get motherCandidates => _motherCandidates;

  /// `RV-09` — fecha futura. Bloquea el envío.
  bool get isDateInFuture => _dateInFuture;

  /// Nacieron más crías que huevos anotados. También bloquea: es una
  /// contradicción aritmética, no una imprecisión del criador.
  bool get isHatchedOverEggs => _hatchedOverEggs;

  int get minHatched => ClutchesRepository.minHatched;
  int get maxHatched => ClutchesRepository.maxHatched;

  bool get canDecrement => _hatched > minHatched;
  bool get canIncrement => _hatched < maxHatched;
  bool get canSubmit => !_dateInFuture && !_hatchedOverEggs && !isLoading;

  /// Primera placa que se asignará. Se muestra desde el principio porque es la
  /// pregunta que el criador se hace al abrir la pantalla — `RF-REG-10`.
  int get firstPlate => _firstPlate;

  /// Última placa del bloque. Con una sola cría coincide con la primera.
  int get lastPlate => _firstPlate + _hatched - 1;

  /// Prepara la pantalla. Se vuelve a llamar tras registrar, cuando el criador
  /// elige «Registrar otra», así que deja el formulario **en blanco**: arrastrar
  /// las cinco crías o los progenitores de la camada anterior crearía registros
  /// equivocados sin que nadie lo note, y la vista ya limpia sus campos.
  Future<void> load() async {
    setLoading();

    _date = _today();
    _hatched = 1;
    _eggs = '';
    _fatherId = null;
    _motherId = null;
    _line = '';
    _notes = '';
    _dateInFuture = false;
    _hatchedOverEggs = false;

    _firstPlate = await _repository.nextPlate(_ownerId);

    final fathers = await _birdsRepository.parentCandidates(ownerId: _ownerId, sex: Sex.male);
    final mothers = await _birdsRepository.parentCandidates(ownerId: _ownerId, sex: Sex.female);
    _fatherCandidates = fathers.valueOrNull ?? const [];
    _motherCandidates = mothers.valueOrNull ?? const [];

    setReady();
  }

  void setDate(DateTime value) {
    _date = value;
    // La fecha se elige en un calendario, no se escribe: validarla al momento
    // no interrumpe a nadie, y esperar a enviar sería peor.
    _dateInFuture = value.isAfter(_endOfToday());
    safeNotify();
  }

  /// El contador es la vía principal: se toca `+` ocho veces, no se escribe.
  void increment() {
    if (!canIncrement) return;
    _hatched++;
    _recheckEggs();
    safeNotify();
  }

  void decrement() {
    if (!canDecrement) return;
    _hatched--;
    _recheckEggs();
    safeNotify();
  }

  /// Fija el número de crías directamente, para camadas grandes donde pulsar
  /// veinte veces sería absurdo.
  void setHatched(int value) {
    _hatched = value.clamp(minHatched, maxHatched);
    _recheckEggs();
    safeNotify();
  }

  void setEggs(String value) {
    _eggs = value;
    _recheckEggs();
    safeNotify();
  }

  void setFatherId(String? value) {
    _fatherId = value;
    safeNotify();
  }

  void setMotherId(String? value) {
    _motherId = value;
    safeNotify();
  }

  void setLine(String value) => _line = value;

  void setNotes(String value) => _notes = value;

  /// Devuelve la camada creada con sus crías, o `null` si no se pudo. La View
  /// decide entonces si celebra o muestra el error.
  Future<ClutchRegistration?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final result = await _repository.register(
      ownerId: _ownerId,
      date: _date,
      hatched: _hatched,
      eggs: _parsedEggs(),
      fatherId: _fatherId,
      motherId: _motherId,
      line: _line,
      notes: _notes,
    );

    return result.fold(
      ok: (registration) {
        setReady();
        return registration;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }

  void _recheckEggs() {
    final eggs = _parsedEggs();
    _hatchedOverEggs = eggs != null && _hatched > eggs;
  }

  int? _parsedEggs() {
    final trimmed = _eggs.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  DateTime _today() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _endOfToday() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }
}
