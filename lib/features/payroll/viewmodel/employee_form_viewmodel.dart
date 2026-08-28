import '../../../core/base/base_viewmodel.dart';
import '../../../core/media/photo_service.dart';
import '../../../core/utils/validators.dart';
import '../model/employee.dart';
import '../repository/payroll_repository.dart';

/// Alta y edición de un empleado — `RF-NOM-01`.
class EmployeeFormViewModel extends BaseViewModel {
  EmployeeFormViewModel({
    required PayrollRepository repository,
    required PhotoService photoService,
    required String ownerId,
    String? employeeId,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _photoService = photoService,
       _ownerId = ownerId,
       _employeeId = employeeId,
       _clock = clock;

  final PayrollRepository _repository;
  final PhotoService _photoService;
  final String _ownerId;
  final String? _employeeId;
  final DateTime Function() _clock;

  Employee? _existing;

  String _name = '';
  String _role = '';
  String _phone = '';
  String _document = '';
  String _salary = '';
  PayFrequency _frequency = PayFrequency.biweekly;
  bool _isActive = true;
  DateTime? _startDate;
  String? _photoPath;
  bool _capturingPhoto = false;

  ValidationError? _nameError;

  String get name => _name;
  String get role => _role;
  String get phone => _phone;
  String get document => _document;
  String get salary => _salary;
  PayFrequency get frequency => _frequency;
  bool get isActive => _isActive;
  DateTime? get startDate => _startDate;
  String? get photoPath => _photoPath;
  bool get isCapturingPhoto => _capturingPhoto;
  ValidationError? get nameError => _nameError;

  bool get isEditing => _employeeId != null;

  /// `RV-17` — la cédula se **advierte**, no se bloquea.
  ///
  /// Vacía no advierte: el campo es opcional y marcarlo en rojo por no
  /// rellenarlo sería un error de la app, no del criador.
  bool get isDocumentSuspicious =>
      _document.trim().isNotEmpty && !Validators.isValidDominicanId(_document);

  bool get canSubmit => _name.trim().isNotEmpty && _parsedCents() > 0 && !isLoading;

  Future<void> load() async {
    final id = _employeeId;
    if (id == null) {
      setReady();
      return;
    }

    setLoading();
    final employee = await _repository.findEmployee(id);
    if (employee == null) {
      setReady();
      return;
    }

    _existing = employee;
    _name = employee.name;
    _role = employee.role ?? '';
    _phone = employee.phone ?? '';
    _document = employee.document ?? '';
    _salary = _formatCents(employee.salaryCents);
    _frequency = employee.frequency;
    _isActive = employee.isActive;
    _startDate = employee.startDate;
    _photoPath = employee.photoPath;
    setReady();
  }

  void setName(String value) {
    _name = value;
    safeNotify();
  }

  /// `RF-AUT-05` vale para todo el producto: se valida al perder el foco, nunca
  /// mientras se escribe.
  void validateName() {
    _nameError = Validators.required(_name);
    safeNotify();
  }

  void setRole(String value) => _role = value;
  void setPhone(String value) => _phone = value;

  void setDocument(String value) {
    _document = value;
    safeNotify();
  }

  void setSalary(String value) {
    _salary = value;
    safeNotify();
  }

  void setFrequency(PayFrequency value) {
    _frequency = value;
    safeNotify();
  }

  /// Cámara o galería. Cancelar no cambia nada ni avisa.
  Future<void> capturePhoto(PhotoSource source) async {
    _capturingPhoto = true;
    safeNotify();

    final path = await _photoService.capture(source);
    if (path != null) {
      // La anterior se borra solo cuando la nueva ya está en disco: si la
      // captura falla, el empleado conserva la foto que tenía.
      final previous = _photoPath;
      _photoPath = path;
      if (previous != null && previous != path) await _photoService.deleteFile(previous);
    }

    _capturingPhoto = false;
    safeNotify();
  }

  void removePhoto() {
    _photoPath = null;
    safeNotify();
  }

  void setStartDate(DateTime? value) {
    _startDate = value;
    safeNotify();
  }

  void setActive({required bool value}) {
    _isActive = value;
    safeNotify();
  }

  Future<Employee?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final now = _clock();
    final result = await _repository.saveEmployee(
      Employee(
        id: _employeeId ?? '',
        ownerId: _ownerId,
        name: _name,
        role: _role,
        phone: _phone,
        document: _document,
        salaryCents: _parsedCents(),
        frequency: _frequency,
        isActive: _isActive,
        startDate: _startDate,
        photoPath: _photoPath,
        // Cambiar o quitar la foto **suelta la URL**: la que había describe a
        // la anterior, y dejarla puesta congelaría la foto vieja en los demás
        // dispositivos sin que aquí fallara nada.
        photoUrl: _photoPath == _existing?.photoPath ? _existing?.photoUrl : null,
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );

    return result.fold(
      ok: (employee) {
        setReady();
        return employee;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }

  /// Acepta coma o punto: en República Dominicana se usa el punto, pero el
  /// teclado del teléfono ofrece a menudo la coma.
  int _parsedCents() {
    final trimmed = _salary.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return 0;
    final value = double.tryParse(trimmed);
    if (value == null || value <= 0) return 0;
    return Money.centsOf(value);
  }

  static String _formatCents(int cents) => (cents / 100).toStringAsFixed(2);
}
