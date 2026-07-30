import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level theme mode.
///
/// [system] — follow OS dark/light + use OS accent colour (Material You on Android,
///   Windows DWM accent on desktop).
/// [light] — forced light theme, accent from system.
/// [dark]  — forced dark theme, accent from system.
/// [original] — the hard-coded dark theme FurClient shipped with (always dark,
///   cyan accent, no system colour injection).
enum AppThemeMode {
  system('System'),
  light('Light'),
  dark('Dark'),
  original('Original');

  const AppThemeMode(this.label);
  final String label;
}

class ThemeProvider extends ChangeNotifier {
  static const _modeKey = 'app_theme_mode';

  /// Singleton instance initialised before runApp so the theme is ready
  /// from the first frame.
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._() {
    // _load() is async — caller must await _loadFromPrefs() separately
    // before first build.
  }

  /// Load theme mode from prefs — call before runApp.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_modeKey) ?? AppThemeMode.original.index;
    _mode = AppThemeMode.values[idx];
  }

  /// Legacy constructor for backwards compatibility — delegates to [instance].
  ThemeProvider() : this._();

  AppThemeMode _mode = AppThemeMode.original;
  AppThemeMode get mode => _mode;

  Future<void> setMode(AppThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, newMode.index);
    notifyListeners();
  }

  /// Resolve to Flutter [ThemeMode] for MaterialApp / FluentApp.
  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.original:
        // original is always dark
        return ThemeMode.dark;
    }
  }

  /// Whether we should inject the system accent colour.
  /// For [original] we keep the hand-picked cyan palette.
  bool get useSystemAccent => _mode != AppThemeMode.original;
}
