import '../../../core/base/base_viewmodel.dart';
import '../../../core/error/failure.dart';
import '../model/bird.dart';
import '../model/clutch.dart';
import '../repository/clutches_repository.dart';

/// Registro de camada — pantalla 21, `RF-REG-08` a `RF-REG-10`.
///
/// La promesa es registrar ocho crías en menos de un minuto, así que el estado
/// arranca ya utilizable: fecha de hoy, una cría, y la placa siguiente del
/// criadero calculada. Solo la fecha y el número de crías son obligatorios; el
/// resto se puede completar después desde cada ficha.
class ClutchFormViewModel extends BaseViewModel {
  ClutchFormViewModel({
    required ClutchesRepository repository,
    required String ownerId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _clock = clock;

  final ClutchesRepository _repository;
  final String _ownerId;
  final DateTime Function() _clock;

  DateTime _date = DateTime.now();
  int _hatched = 1;
  String _eggs = '';
  Bird? _father;
  Bird? _mother;
  String _line = '';
  String _notes = '';

  int _firstPlate = 1;

  bool _dateInFuture = false;
  bool _hatchedOverEggs = false;
  PlanLimitFailure? _planLimit;

  DateTime get date => _date;
  int get hatched => _hatched;
  String get eggs => _eggs;
  Bird? get father => _father;
  Bird? get mother => _mother;

  /// Lo que viaja al repositorio. Se deriva del ejemplar elegido para que no
  /// puedan quedar desincronizados el id y el nombre que se está mostrando.
  String? get fatherId => _father?.id;
  String? get motherId => _mother?.id;
  String get line => _line;
  String get notes => _notes;

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
  /// pregunta que el criador se hace al abrir la pantalla — `RF-REG-09`.
  int get firstPlate => _firstPlate;

  /// Última placa del bloque. Con una sola cría coincide con la primera.
  int get lastPlate => _firstPlate + _hatched - 1;

  /// Tope de plan alcanzado al confirmar — CU-02 alterno B.
  ///
  /// No se trata como error: que el plan se llene no es un fallo de la app sino
  /// una decisión que el criador tiene que tomar, y la pantalla se la plantea
  /// con el número exacto en vez de un mensaje genérico.
  PlanLimitFailure? get planLimit => _planLimit;

  /// Cuántas crías caben todavía. Cero significa que no cabe ninguna.
  int get planLimitFits {
    final limit = _planLimit;
    if (limit == null) return 0;
    return (limit.limit - limit.current).clamp(0, maxHatched);
  }

  void clearPlanLimit() {
    _planLimit = null;
    safeNotify();
  }

  /// Prepara la pantalla. Se vuelve a llamar tras registrar, cuando el criador
  /// elige «Registrar otra», así que deja el formulario **en blanco**: arrastrar
  /// las cinco crías o los progenitores de la camada anterior crearía registros
  /// equivocados sin que nadie lo note, y la vista ya limpia sus campos.
  Future<void> load() async {
    setLoading();

    _date = _today();
    _hatched = 1;
    _eggs = '';
    _father = null;
    _mother = null;
    _line = '';
    _notes = '';
    _dateInFuture = false;
    _hatchedOverEggs = false;
    _planLimit = null;

    _firstPlate = await _repository.nextPlate(_ownerId);
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

  /// Lo elige la pantalla 18 (`RF-REG-11`). `null` es «sin registrar», una
  /// respuesta legítima: el progenitor puede no estar en el libro.
  void setFather(Bird? value) {
    _father = value;
    safeNotify();
  }

  void setMother(Bird? value) {
    _mother = value;
    safeNotify();
  }

  void setLine(String value) => _line = value;

  void setNotes(String value) => _notes = value;

  /// Devuelve la camada creada con sus crías, o `null` si no se pudo. La View
  /// decide entonces si celebra o muestra el error.
  Future<ClutchRegistration?> submit() async {
    if (!canSubmit) return null;

    _planLimit = null;
    setLoading();
    final result = await _repository.register(
      ownerId: _ownerId,
      date: _date,
      hatched: _hatched,
      eggs: _parsedEggs(),
      fatherId: fatherId,
      motherId: motherId,
      line: _line,
      notes: _notes,
    );

    return result.fold(
      ok: (registration) {
        setReady();
        return registration;
      },
      err: (failure) {
        // El límite de plan sale por su propia vía: la pantalla ofrece
        // registrar las que caben (CU-02 alterno B), no un error que solo
        // dice que no se pudo.
        if (failure is PlanLimitFailure) {
          _planLimit = failure;
          setReady();
          return null;
        }
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
