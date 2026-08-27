import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/error/failure.dart';
import '../model/employee.dart';
import '../model/payroll_payment.dart';
import '../repository/payroll_repository.dart';

/// Panel de empleomanía — `RF-NOM-01`, `RF-NOM-02` y `RS-07`.
class PayrollViewModel extends BaseViewModel {
  PayrollViewModel({required PayrollRepository repository, required String ownerId})
    : _repository = repository,
      _ownerId = ownerId {
    _subscribe();
  }

  final PayrollRepository _repository;
  final String _ownerId;

  StreamSubscription<List<Employee>>? _employeesSubscription;
  StreamSubscription<PayrollSummary>? _summarySubscription;
  StreamSubscription<List<PayrollPayment>>? _paymentsSubscription;

  List<Employee> _employees = const [];
  List<PayrollPayment> _payments = const [];
  PayrollSummary _summary = const PayrollSummary.empty();
  bool _isAvailable = true;

  List<Employee> get employees => _employees;
  List<PayrollPayment> get payments => _payments;
  PayrollSummary get summary => _summary;

  /// El módulo es de Élite (PRD §6). Como en pruebas de campo, la pantalla
  /// **no se oculta**: se muestra con su aviso. Esconderla dejaría al criador
  /// sin saber que existe, y esta es la función que justifica el plan caro.
  bool get isAvailable => _isAvailable;

  bool get hasEmployees => _employees.isNotEmpty;

  /// Nombre del empleado de un pago, para el historial. Los pagos guardan solo
  /// el id: el nombre puede cambiar y el pago no debe reescribirse por eso.
  String? nameOf(String employeeId) {
    for (final employee in _employees) {
      if (employee.id == employeeId) return employee.name;
    }
    return null;
  }

  Future<void> load() async {
    _isAvailable = await _repository.isAvailableFor(_ownerId);
    safeNotify();
  }

  Future<bool> setActive(String id, {required bool isActive}) async {
    final result = await _repository.setActive(id, isActive: isActive);
    return result.fold(
      ok: (_) => true,
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  Future<bool> voidPayment(String id) async {
    final result = await _repository.voidPayment(id);
    return result.fold(
      ok: (_) => true,
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  /// Un stream que falla no puede quedarse callado: una lista vacía por error
  /// se lee como «no hay empleados», que es justo la conclusión equivocada.
  void _reportStreamError(Object error) =>
      setFailure(DatabaseFailure(debugMessage: error.toString(), cause: error));

  void _subscribe() {
    setLoading();

    _employeesSubscription = _repository.watchEmployees(ownerId: _ownerId).listen((employees) {
      _employees = employees;
      setReady();
    }, onError: _reportStreamError);

    _summarySubscription = _repository.watchSummary(_ownerId).listen((summary) {
      _summary = summary;
      safeNotify();
    }, onError: _reportStreamError);

    _paymentsSubscription = _repository.watchPayments(ownerId: _ownerId).listen((payments) {
      _payments = payments;
      safeNotify();
    }, onError: _reportStreamError);
  }

  @override
  void dispose() {
    _employeesSubscription?.cancel();
    _summarySubscription?.cancel();
    _paymentsSubscription?.cancel();
    super.dispose();
  }
}
