import '../../../core/base/base_viewmodel.dart';
import '../model/transaction.dart';
import '../repository/transactions_repository.dart';

/// Registro de un movimiento — pantalla 30, `RF-CON-01` a `RF-CON-03`.
class TransactionFormViewModel extends BaseViewModel {
  TransactionFormViewModel({
    required TransactionsRepository repository,
    required String ownerId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _clock = clock;

  final TransactionsRepository _repository;
  final String _ownerId;
  final DateTime Function() _clock;

  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.feed;
  String _amount = '';
  DateTime _date = DateTime.now();
  String _description = '';
  Recurrence _recurrence = Recurrence.none;
  bool _dateInFuture = false;

  TransactionType get type => _type;
  TransactionCategory get category => _category;
  String get amount => _amount;
  DateTime get date => _date;
  String get description => _description;
  Recurrence get recurrence => _recurrence;
  bool get isDateInFuture => _dateInFuture;

  /// `RF-CON-02` — solo las del tipo elegido, y nunca la de nómina.
  List<TransactionCategory> get categories => TransactionCategory.selectableFor(_type);

  bool get canSubmit => _parsedCents() > 0 && !_dateInFuture && !isLoading;

  Future<void> load() async {
    setLoading();
    final now = _clock();
    _date = DateTime(now.year, now.month, now.day);
    setReady();
  }

  /// Cambiar de tipo cambia el catálogo: la categoría anterior ya no vale, y
  /// dejarla puesta guardaría un «alimento» como ingreso.
  void setType(TransactionType value) {
    if (_type == value) return;
    _type = value;
    _category = categories.first;
    safeNotify();
  }

  void setCategory(TransactionCategory value) {
    _category = value;
    safeNotify();
  }

  void setAmount(String value) {
    _amount = value;
    safeNotify();
  }

  void setDate(DateTime value) {
    _date = value;
    final now = _clock();
    _dateInFuture = value.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
    safeNotify();
  }

  void setDescription(String value) => _description = value;

  void setRecurrence(Recurrence value) {
    _recurrence = value;
    safeNotify();
  }

  Future<Transaction?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final now = _clock();
    final result = await _repository.save(
      Transaction(
        id: '',
        ownerId: _ownerId,
        type: _type,
        category: _category,
        amountCents: _parsedCents(),
        date: _date,
        description: _description,
        recurrence: _recurrence,
        createdAt: now,
        updatedAt: now,
      ),
    );

    return result.fold(
      ok: (transaction) {
        setReady();
        return transaction;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }

  /// Acepta coma o punto como separador decimal: en República Dominicana se usa
  /// el punto, pero el teclado del teléfono ofrece a menudo la coma.
  int _parsedCents() {
    final trimmed = _amount.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return 0;
    final value = double.tryParse(trimmed);
    if (value == null || value <= 0) return 0;
    return Transaction.centsOf(value);
  }
}
