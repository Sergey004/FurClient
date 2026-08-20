import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level theme mode.
///
/// [system] — follow OS dark/light + use OS accent colour (Material You on Android,
///   Windows DWM accent on desktop).
/// [light] — forced light theme, accent from system.
/// [dark]  — forced dark theme, accent from system.
enum AppThemeMode {
  system('System'),
  light('Light'),
  dark('Dark');

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
    final savedIndex = prefs.getInt(_modeKey);
    // Index 3 belonged to the removed Original theme.
    final index = savedIndex == null || savedIndex >= AppThemeMode.values.length
        ? AppThemeMode.system.index
        : savedIndex;
    _mode = AppThemeMode.values[index];
  }

  /// Legacy constructor for backwards compatibility — delegates to [instance].
  ThemeProvider() : this._();

  AppThemeMode _mode = AppThemeMode.system;
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
    }
  }

  /// Material You always uses the active system or dynamic accent.
  bool get useSystemAccent => true;
}
