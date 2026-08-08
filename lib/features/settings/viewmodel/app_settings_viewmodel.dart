import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/base/base_viewmodel.dart';

/// Preferencias de presentación de la app: tema e idioma.
///
/// Es la única excepción a "el ViewModel no importa material": [ThemeMode] y
/// [Locale] son precisamente los valores que hay que entregarle al
/// `MaterialApp`. Vive por encima del router porque afecta a toda la app.
class AppSettingsViewModel extends BaseViewModel {
  AppSettingsViewModel(this._preferences) {
    _restore();
  }

  static const _themeKey = 'settings.theme_mode';
  static const _localeKey = 'settings.locale';

  final SharedPreferences _preferences;

  ThemeMode _themeMode = ThemeMode.system;

  /// `null` significa "seguir el idioma del dispositivo".
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    safeNotify();
    await _preferences.setString(_themeKey, mode.name);
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    safeNotify();
    if (locale == null) {
      await _preferences.remove(_localeKey);
    } else {
      await _preferences.setString(_localeKey, locale.languageCode);
    }
  }

  void _restore() {
    final storedTheme = _preferences.getString(_themeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == storedTheme,
      orElse: () => ThemeMode.system,
    );

    final storedLocale = _preferences.getString(_localeKey);
    _locale = storedLocale == null ? null : Locale(storedLocale);
  }
}
