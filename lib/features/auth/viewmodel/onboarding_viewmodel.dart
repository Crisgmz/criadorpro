import '../../../core/base/base_viewmodel.dart';
import '../repository/auth_preferences.dart';

/// Las tres láminas de bienvenida — `RF-AUT-02`.
///
/// El contenido no vive aquí: la View resuelve título y texto por índice desde
/// los archivos de traducción (`RNF-27`).
enum OnboardingSlide { batchRegistration, genealogy, backup }

class OnboardingViewModel extends BaseViewModel {
  OnboardingViewModel(this._preferences);

  final AuthPreferences _preferences;

  int _index = 0;

  int get index => _index;
  OnboardingSlide get slide => OnboardingSlide.values[_index];
  int get slideCount => OnboardingSlide.values.length;
  bool get isLastSlide => _index == slideCount - 1;

  void goTo(int index) {
    if (index == _index || index < 0 || index >= slideCount) return;
    _index = index;
    safeNotify();
  }

  /// Marca el onboarding como visto. Se llama tanto al terminar la última
  /// lámina como al pulsar «Saltar»: en ambos casos ya no debe volver a
  /// aparecer.
  Future<void> complete() => _preferences.markOnboardingSeen();
}
