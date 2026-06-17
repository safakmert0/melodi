import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFF1DB954);

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

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

  Future<void> loadSettings() async {
    final db = DatabaseService.instance;
    final mode = await db.getSetting('theme_mode');
    if (mode != null) {
      _themeMode = ThemeMode.values[int.parse(mode)];
    }
    final colorStr = await db.getSetting('accent_color');
    if (colorStr != null) {
      _accentColor = Color(int.parse(colorStr));
    }
    AppTheme.accentColor = _accentColor;
    _syncIsLightMode();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _syncIsLightMode();
    await DatabaseService.instance.setSetting('theme_mode', mode.index.toString());
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    AppTheme.accentColor = color;
    await DatabaseService.instance.setSetting('accent_color', color.value.toString());
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
    _syncIsLightMode();
    notifyListeners();
  }

  ThemeData get lightTheme => _buildLightTheme();
  ThemeData get darkTheme => _buildDarkTheme();

  ThemeData get currentTheme {
    switch (_themeMode) {
      case ThemeMode.light:
        return lightTheme;
      case ThemeMode.dark:
        return darkTheme;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light
            ? lightTheme
            : darkTheme;
    }
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: AppTheme.lightBackground,
      colorScheme: ColorScheme.light(
        primary: _accentColor,
        secondary: _accentColor,
        surface: AppTheme.lightSurface,
        error: AppTheme.errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFF1A1A1A),
        unselectedItemColor: Color(0xFF999999),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFEEEEEE),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF666666)),
        bodySmall: TextStyle(color: Color(0xFF999999)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFD0D0D0), thickness: 0.5),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accentColor,
        inactiveTrackColor: const Color(0xFFD0D0D0),
        thumbColor: const Color(0xFF1A1A1A),
        overlayColor: _accentColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: AppTheme.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: _accentColor,
        secondary: _accentColor,
        surface: AppTheme.darkSurface,
        error: AppTheme.errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF727272),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF282828),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFB3B3B3)),
        bodySmall: TextStyle(color: Color(0xFF727272)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF404040), thickness: 0.5),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accentColor,
        inactiveTrackColor: const Color(0xFF404040),
        thumbColor: Colors.white,
        overlayColor: _accentColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }
}
