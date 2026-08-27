import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../auth/model/profile.dart';
import '../../auth/repository/profile_repository.dart';

/// Pantalla 13 — Mi perfil.
class ProfileViewModel extends BaseViewModel {
  ProfileViewModel({required ProfileRepository repository, required String ownerId})
    : _repository = repository,
      _ownerId = ownerId;

  final ProfileRepository _repository;
  final String _ownerId;

  Profile? _profile;

  String _fullName = '';
  String _farmName = '';
  String _location = '';
  String _phone = '';
  String? _locale;

  Profile? get profile => _profile;
  String get fullName => _fullName;
  String get farmName => _farmName;
  String get location => _location;
  String get phone => _phone;
  String? get locale => _locale;

  /// La placa que se asignará al próximo ejemplar. **Se muestra, no se edita**:
  /// retrocederla repetiría placas ya usadas, que es lo único que `RS-01` no
  /// perdona. Quien la mueve es la reserva del alta.
  int get nextPlate => _profile?.nextPlate ?? 1;

  /// El criadero es lo único obligatorio: sin nombre, la guardia del router
  /// devuelve al criador a la configuración inicial.
  bool get canSubmit => _farmName.trim().isNotEmpty && !isLoading;

  Future<void> load() async {
    setLoading();
    final result = await _repository.findById(_ownerId);
    result.fold(
      ok: (profile) {
        _profile = profile;
        _fullName = profile.fullName ?? '';
        _farmName = profile.farmName ?? '';
        _location = profile.location ?? '';
        _phone = profile.phone ?? '';
        _locale = profile.locale;
        setReady();
      },
      err: setFailure,
    );
  }

  void setFullName(String value) {
    _fullName = value;
    safeNotify();
  }

  void setFarmName(String value) {
    _farmName = value;
    safeNotify();
  }

  void setLocation(String value) => _location = value;
  void setPhone(String value) => _phone = value;

  void setLocale(String? value) {
    _locale = value;
    safeNotify();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;

    setLoading();
    final result = await _repository.updateProfile(
      ownerId: _ownerId,
      fullName: _fullName,
      farmName: _farmName,
      location: _location,
      phone: _phone,
      locale: _locale,
    );

    return result.fold(
      ok: (profile) {
        _profile = profile;
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
