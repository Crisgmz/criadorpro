import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/error/failure.dart';
import '../model/transaction.dart';
import '../repository/transactions_repository.dart';

/// Cierre mensual — pantalla 29, `RF-CON-04` a `RF-CON-06`.
class AccountingViewModel extends BaseViewModel {
  AccountingViewModel({
    required TransactionsRepository repository,
    required String ownerId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _clock = clock {
    final now = clock();
    _month = DateTime(now.year, now.month);
  }

  final TransactionsRepository _repository;
  final String _ownerId;
  final DateTime Function() _clock;

  StreamSubscription<List<Transaction>>? _subscription;
  StreamSubscription<MonthlyBalance>? _balanceSubscription;

  late DateTime _month;
  List<Transaction> _transactions = const [];
  MonthlyBalance? _balance;
  List<DateTime> _monthsWithData = const [];
  bool _isAvailable = true;

  DateTime get month => _month;
  List<Transaction> get transactions => _transactions;
  MonthlyBalance get balance => _balance ?? MonthlyBalance.emptyFor(_month);
  bool get isAvailable => _isAvailable;

  /// No se puede avanzar más allá del mes en curso: no hay nada que enseñar y
  /// dejaría al criador paseando por meses vacíos.
  bool get canGoForward {
    final now = _clock();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  /// `RF-CON-05` — hacia atrás solo mientras haya datos que consultar.
  bool get canGoBack => _monthsWithData.any((m) => m.isBefore(_month));

  Future<void> load() async {
    setLoading();
    _isAvailable = await _repository.isAvailableFor(_ownerId);

    if (_isAvailable) {
      // `RS-08`: los recurrentes vencidos se generan al abrir.
      await _repository.generateDueRecurrences(_ownerId);
      _monthsWithData = await _repository.monthsWithData(_ownerId);
      _subscribe();
    }
    setReady();
  }

  void goToPreviousMonth() {
    if (!canGoBack) return;
    _setMonth(DateTime(_month.year, _month.month - 1));
  }

  void goToNextMonth() {
    if (!canGoForward) return;
    _setMonth(DateTime(_month.year, _month.month + 1));
  }

  Future<bool> delete(String id) async {
    final result = await _repository.delete(id);
    return result.fold(
      ok: (_) => true,
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  /// Se relee tras registrar: un movimiento en un mes que antes estaba vacío
  /// tiene que habilitar la navegación hacia él.
  Future<void> refreshMonths() async {
    _monthsWithData = await _repository.monthsWithData(_ownerId);
    safeNotify();
  }

  void _setMonth(DateTime value) {
    _month = value;
    _subscribe();
    safeNotify();
  }

  void _subscribe() {
    _subscription?.cancel();
    _balanceSubscription?.cancel();

    _subscription = _repository.watchMonth(ownerId: _ownerId, month: _month).listen((rows) {
      _transactions = rows;
      safeNotify();
    }, onError: _reportStreamError);

    _balanceSubscription = _repository.watchBalance(ownerId: _ownerId, month: _month).listen((
      balance,
    ) {
      _balance = balance;
      safeNotify();
    }, onError: _reportStreamError);
  }

  /// Un stream que falla no puede quedarse callado: la pantalla mostraría un
  /// vacío que se lee como «no hay datos» cuando en realidad la consulta se
  /// rompió. Así llega al estado y la vista lo cuenta.
  void _reportStreamError(Object error) =>
      setFailure(DatabaseFailure(debugMessage: error.toString(), cause: error));

  @override
  void dispose() {
    _subscription?.cancel();
    _balanceSubscription?.cancel();
    super.dispose();
  }
}
