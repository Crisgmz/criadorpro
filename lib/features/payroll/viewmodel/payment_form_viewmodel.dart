import '../../../core/base/base_viewmodel.dart';
import '../model/employee.dart';
import '../model/payroll_payment.dart';
import '../repository/payroll_repository.dart';

/// Registro de un pago de nómina — `RF-NOM-03`, `RS-06` y `RV-15`.
class PaymentFormViewModel extends BaseViewModel {
  PaymentFormViewModel({
    required PayrollRepository repository,
    required String ownerId,
    required String employeeId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _employeeId = employeeId,
       _clock = clock;

  final PayrollRepository _repository;
  final String _ownerId;
  final String _employeeId;
  final DateTime Function() _clock;

  Employee? _employee;

  late DateTime _periodStart = _clock();
  late DateTime _periodEnd = _clock();
  String _base = '';
  String _bonus = '';
  String _deductions = '';
  PaymentMethod _method = PaymentMethod.cash;
  List<PayrollPayment> _overlapping = const [];

  Employee? get employee => _employee;
  DateTime get periodStart => _periodStart;
  DateTime get periodEnd => _periodEnd;
  String get base => _base;
  String get bonus => _bonus;
  String get deductions => _deductions;
  PaymentMethod get method => _method;

  int get baseCents => _parse(_base);
  int get bonusCents => _parse(_bonus);
  int get deductionsCents => _parse(_deductions);

  /// Neto calculado en vivo — el criador ve la cuenta antes de confirmar.
  int get netCents => baseCents + bonusCents - deductionsCents;

  /// `RV-15` — «El neto no puede ser negativo». Bloquea el envío.
  bool get isNetNegative => netCents < 0;

  /// Ya hay un pago vivo que cubre parte de este período. Es **advertencia**,
  /// no bloqueo: un adelanto o un ajuste sobre el mismo período son legítimos,
  /// y lo que se quiere evitar es el duplicado por descuido.
  bool get hasOverlap => _overlapping.isNotEmpty;

  bool get canSubmit => baseCents > 0 && !isNetNegative && !isLoading;

  Future<void> load() async {
    setLoading();

    final employee = await _repository.findEmployee(_employeeId);
    if (employee == null) {
      setReady();
      return;
    }

    _employee = employee;
    // El período y la base vienen propuestos: en el galpón, teclear cuatro
    // campos por empleado y por quincena es lo que hace que se abandone la app.
    final period = await _repository.suggestPeriodFor(employee);
    _periodStart = period.start;
    _periodEnd = period.end;
    _base = (employee.salaryCents / 100).toStringAsFixed(2);

    await _checkOverlap();
    setReady();
  }

  Future<void> setPeriodStart(DateTime value) async {
    _periodStart = value;
    if (_periodEnd.isBefore(value)) _periodEnd = value;
    await _checkOverlap();
    safeNotify();
  }

  Future<void> setPeriodEnd(DateTime value) async {
    _periodEnd = value;
    if (value.isBefore(_periodStart)) _periodStart = value;
    await _checkOverlap();
    safeNotify();
  }

  void setBase(String value) {
    _base = value;
    safeNotify();
  }

  void setBonus(String value) {
    _bonus = value;
    safeNotify();
  }

  void setDeductions(String value) {
    _deductions = value;
    safeNotify();
  }

  void setMethod(PaymentMethod value) {
    _method = value;
    safeNotify();
  }

  Future<PayrollPayment?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final now = _clock();
    final result = await _repository.confirmPayment(
      PayrollPayment(
        id: '',
        ownerId: _ownerId,
        employeeId: _employeeId,
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        baseCents: baseCents,
        bonusCents: bonusCents,
        deductionsCents: deductionsCents,
        method: _method,
        createdAt: now,
        updatedAt: now,
      ),
    );

    return result.fold(
      ok: (payment) {
        setReady();
        return payment;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }

  Future<void> _checkOverlap() async {
    _overlapping = await _repository.overlappingPayments(
      employeeId: _employeeId,
      start: _periodStart,
      end: _periodEnd,
    );
  }

  int _parse(String value) {
    final trimmed = value.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return 0;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < 0) return 0;
    return Money.centsOf(parsed);
  }
}
