import 'package:flutter/material.dart';
import '../core/constants.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;

  void _syncIsLightMode() {
    switch (_themeMode) {
      case ThemeMode.light:
        AppTheme.isLightMode = true;
        break;
      case ThemeMode.dark:
        AppTheme.isLightMode = false;
        break;
      case ThemeMode.system:
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        AppTheme.isLightMode = brightness == Brightness.light;
        break;
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _syncIsLightMode();
    notifyListeners();
  }

  void toggleTheme() {
    switch (_themeMode) {
      case ThemeMode.dark:
        _themeMode = ThemeMode.light;
        break;
      case ThemeMode.light:
        _themeMode = ThemeMode.system;
        break;
      case ThemeMode.system:
        _themeMode = ThemeMode.dark;
        break;
    }
    notifyListeners();
  }

  ThemeData get currentTheme {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppTheme.lightTheme;
      case ThemeMode.dark:
        return AppTheme.darkTheme;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
    }
  }
}
