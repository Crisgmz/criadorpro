import '../../../core/base/base_viewmodel.dart';
import '../../../core/utils/validators.dart';
import '../model/weight_entry.dart';
import '../repository/weights_repository.dart';

/// Anotar una pesada — `RF-REG-14`.
class WeightFormViewModel extends BaseViewModel {
  WeightFormViewModel({
    required WeightsRepository repository,
    required String ownerId,
    required String birdId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _birdId = birdId,
       _clock = clock {
    final now = _clock();
    _date = DateTime(now.year, now.month, now.day);
  }

  final WeightsRepository _repository;
  final String _ownerId;
  final String _birdId;
  final DateTime Function() _clock;

  String _weight = '';
  late DateTime _date;
  String _notes = '';

  String get weight => _weight;
  DateTime get date => _date;

  /// Gramos escritos. El criador teclea en gramos porque es lo que marca la
  /// báscula del galpón; la ficha los presenta en kilos.
  int get grams => int.tryParse(_weight.trim()) ?? 0;

  /// `RV-12` — fuera de 100 a 8.000 g **advierte, no bloquea**. Un pollito de
  /// 90 g existe, y bloquearlo obligaría al criador a mentirle a la app.
  bool get isOutOfRange => grams > 0 && !Validators.isWeightInRange(grams);

  bool get canSubmit => grams > 0 && !isLoading;

  void setWeight(String value) {
    _weight = value;
    safeNotify();
  }

  void setDate(DateTime value) {
    _date = value;
    safeNotify();
  }

  void setNotes(String value) => _notes = value;

  Future<WeightEntry?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final now = _clock();
    final result = await _repository.save(
      WeightEntry(
        id: '',
        ownerId: _ownerId,
        birdId: _birdId,
        weightG: grams,
        date: _date,
        notes: _notes,
        createdAt: now,
        updatedAt: now,
      ),
    );

    return result.fold(
      ok: (entry) {
        setReady();
        return entry;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }
}
