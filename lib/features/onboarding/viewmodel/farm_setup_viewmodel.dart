import '../../../core/base/base_viewmodel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/validators.dart';
import '../../auth/repository/profile_repository.dart';

/// Pasos de la configuración inicial — pantallas 11 a 13.
///
/// La celebración (pantalla 14) no es un paso: se muestra al terminar y no
/// admite vuelta atrás.
enum FarmSetupStep { profile, numbering, plan }

/// Pantallas 11–13 — configuración inicial del criadero.
///
/// Un solo ViewModel para los tres pasos porque comparten un único envío: nada
/// se guarda hasta el final, y `RF-ONB-07` exige poder retomar donde se dejó,
/// lo que obliga a conservar el estado entre pasos.
class FarmSetupViewModel extends BaseViewModel {
  FarmSetupViewModel({required ProfileRepository profiles, required String ownerId})
    : _profiles = profiles,
      _ownerId = ownerId;

  final ProfileRepository _profiles;
  final String _ownerId;

  FarmSetupStep _step = FarmSetupStep.profile;
  String _farmName = '';
  String _location = '';
  String _plate = '';
  ValidationError? _farmNameError;
  ValidationError? _plateError;

  FarmSetupStep get step => _step;
  String get farmName => _farmName.trim();
  bool get isFirstStep => _step == FarmSetupStep.profile;

  ValidationError? get farmNameError => _farmNameError;
  ValidationError? get plateError => _plateError;

  /// Progreso para la barra de la cabecera: 1 de 3, 2 de 3…
  int get stepNumber => _step.index + 1;
  int get stepCount => FarmSetupStep.values.length;
  double get progress => stepNumber / stepCount;

  // --- Captura -------------------------------------------------------------

  void setFarmName(String value) {
    _farmName = value;
    if (_farmNameError != null) {
      _farmNameError = null;
      safeNotify();
    }
  }

  void setLocation(String value) => _location = value;

  void setPlate(String value) {
    _plate = value;
    if (_plateError != null) {
      _plateError = null;
      safeNotify();
    }
  }

  // --- Validación al perder el foco (RF-AUT-05) ---------------------------

  void validateFarmName() {
    _farmNameError = Validators.farmName(_farmName);
    safeNotify();
  }

  void validatePlate() {
    _plateError = Validators.initialPlate(_plate);
    safeNotify();
  }

  // --- Navegación entre pasos ---------------------------------------------

  /// Avanza si el paso actual es válido. `false` significa que hay un error que
  /// la vista debe pintar.
  bool next() {
    switch (_step) {
      case FarmSetupStep.profile:
        validateFarmName();
        if (_farmNameError != null) return false;
        _step = FarmSetupStep.numbering;
      case FarmSetupStep.numbering:
        validatePlate();
        if (_plateError != null) return false;
        _step = FarmSetupStep.plan;
      case FarmSetupStep.plan:
        return true;
    }
    safeNotify();
    return true;
  }

  void back() {
    if (_step == FarmSetupStep.profile) return;
    _step = FarmSetupStep.values[_step.index - 1];
    safeNotify();
  }

  // --- Cierre ---------------------------------------------------------------

  /// Guarda el criadero y la numeración. `true` si quedó registrado.
  ///
  /// El plan no se envía: `RF-ONB-05` permite entrar con Gratis, y contratar es
  /// una compra dentro de la app que solo el servidor puede confirmar
  /// (`RS-12`). Elegir «Pro» aquí no cambia el plan, lleva a la tienda.
  Future<bool> submit({required String locale}) async {
    validateFarmName();
    validatePlate();
    if (_farmNameError != null || _plateError != null) return false;

    setLoading();
    final result = await _profiles.completeOnboarding(
      ownerId: _ownerId,
      farmName: _farmName,
      currentPlate: int.parse(_plate.trim()),
      location: _location.trim().isEmpty ? null : _location,
      locale: AppConfig.supportedLocales.contains(locale) ? locale : AppConfig.defaultLocale,
    );

    return result.fold(
      ok: (_) {
        setReady();
        return true;
      },
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }
}
