import '../../../core/base/base_viewmodel.dart';
import '../../birds/model/bird.dart';
import '../model/evaluation.dart';
import '../repository/evaluations_repository.dart';

/// Registro de una prueba — pantalla 25, `RF-PRU-01` y `RF-PRU-02`.
class EvaluationFormViewModel extends BaseViewModel {
  EvaluationFormViewModel({
    required EvaluationsRepository repository,
    required String ownerId,
    String? birdId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _presetBirdId = birdId,
       _clock = clock;

  final EvaluationsRepository _repository;
  final String _ownerId;

  /// Cuando la prueba se abre desde la ficha de un ejemplar, ya viene elegido.
  final String? _presetBirdId;

  final DateTime Function() _clock;

  Bird? _bird;
  DateTime _date = DateTime.now();
  String _place = '';
  EvaluationResult _result = EvaluationResult.undefined;
  int? _condition;
  EvaluationType _type = EvaluationType.fieldTest;
  String _duration = '';
  int? _stamina;
  int? _agility;
  int? _response;
  FinalCondition? _finalCondition;
  String _weight = '';
  String _notes = '';
  bool _dateInFuture = false;

  Bird? get bird => _bird;
  String? get birdId => _bird?.id ?? _presetBirdId;
  DateTime get date => _date;
  String get place => _place;
  EvaluationResult get result => _result;
  int? get condition => _condition;
  EvaluationType get type => _type;
  String get duration => _duration;
  int? get stamina => _stamina;
  int? get agility => _agility;
  int? get response => _response;
  FinalCondition? get finalCondition => _finalCondition;
  String get weight => _weight;
  String get notes => _notes;

  bool get isDateInFuture => _dateInFuture;

  int get minCondition => EvaluationsRepository.minCondition;
  int get maxCondition => EvaluationsRepository.maxCondition;

  /// El ejemplar es lo único obligatorio — `RF-PRU-02` deja guardar sin
  /// resultado, y el resto de campos son opcionales.
  bool get canSubmit => (birdId ?? '').isNotEmpty && !_dateInFuture && !isLoading;

  /// La ficha del ejemplar fija el sujeto: ahí no se puede cambiar.
  bool get isBirdLocked => _presetBirdId != null;

  Future<void> load() async {
    setLoading();
    final now = _clock();
    _date = DateTime(now.year, now.month, now.day);
    setReady();
  }

  void setBird(Bird? value) {
    _bird = value;
    safeNotify();
  }

  void setDate(DateTime value) {
    _date = value;
    final now = _clock();
    _dateInFuture = value.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
    safeNotify();
  }

  void setPlace(String value) => _place = value;

  void setResult(EvaluationResult value) {
    _result = value;
    safeNotify();
  }

  /// Tocar la condición ya seleccionada la retira: es opcional, y sin esto no
  /// habría forma de deshacer un toque accidental.
  void setType(EvaluationType value) {
    _type = value;
    safeNotify();
  }

  void setDuration(String value) => _duration = value;

  /// Volver a tocar el mismo valor lo quita: sin eso, un índice puesto por
  /// error no se puede retirar y queda un dato que nadie midió.
  void setStamina(int? value) {
    _stamina = _stamina == value ? null : value;
    safeNotify();
  }

  void setAgility(int? value) {
    _agility = _agility == value ? null : value;
    safeNotify();
  }

  void setResponse(int? value) {
    _response = _response == value ? null : value;
    safeNotify();
  }

  void setFinalCondition(FinalCondition? value) {
    _finalCondition = _finalCondition == value ? null : value;
    safeNotify();
  }

  void setCondition(int? value) {
    _condition = _condition == value ? null : value;
    safeNotify();
  }

  void setWeight(String value) => _weight = value;

  void setNotes(String value) => _notes = value;

  Future<Evaluation?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final result = await _repository.save(
      Evaluation(
        id: '',
        ownerId: _ownerId,
        birdId: birdId!,
        date: _date,
        place: _place,
        result: _result,
        condition: _condition,
        type: _type,
        durationMin: int.tryParse(_duration.trim()),
        stamina: _stamina,
        agility: _agility,
        response: _response,
        finalCondition: _finalCondition,
        weightG: _parsedWeight(),
        notes: _notes,
        createdAt: _clock(),
        updatedAt: _clock(),
      ),
    );

    return result.fold(
      ok: (evaluation) {
        setReady();
        return evaluation;
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
}
