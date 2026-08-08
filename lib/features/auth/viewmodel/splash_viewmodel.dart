import '../../../core/base/base_viewmodel.dart';
import '../../../core/config/app_config.dart';
import '../repository/auth_preferences.dart';
import '../repository/auth_repository.dart';

/// A dónde deriva la pantalla de entrada — `RF-AUT-01`.
enum SplashDestination { onboarding, welcome, home }

class SplashViewModel extends BaseViewModel {
  SplashViewModel({required AuthRepository auth, required AuthPreferences preferences})
    : _auth = auth,
      _preferences = preferences;

  final AuthRepository _auth;
  final AuthPreferences _preferences;

  /// Espera los dos segundos de marca y decide. La espera es deliberada: es lo
  /// que fija `RF-AUT-01`, no un disimulo de trabajo pendiente.
  Future<SplashDestination> resolve() async {
    await Future<void>.delayed(AppConfig.splashDuration);

    if (_auth.isSignedIn) return SplashDestination.home;
    if (!_preferences.hasSeenOnboarding) return SplashDestination.onboarding;
    return SplashDestination.welcome;
  }
}
