import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFF1DB954);
  Color? _customBackground;
  Color? _customSurface;
  Color? _customCard;
  Color? _customTextPrimary;
  Color? _customTextSecondary;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  Color? get customBackground => _customBackground;
  Color? get customSurface => _customSurface;
  Color? get customCard => _customCard;
  Color? get customTextPrimary => _customTextPrimary;
  Color? get customTextSecondary => _customTextSecondary;

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

  void _applyCustomColors() {
    AppTheme.customBackground = _customBackground;
    AppTheme.customSurface = _customSurface;
    AppTheme.customCard = _customCard;
    AppTheme.customTextPrimary = _customTextPrimary;
    AppTheme.customTextSecondary = _customTextSecondary;
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

    _customBackground = await _loadColor(db, 'custom_bg');
    _customSurface = await _loadColor(db, 'custom_surface');
    _customCard = await _loadColor(db, 'custom_card');
    _customTextPrimary = await _loadColor(db, 'custom_text_primary');
    _customTextSecondary = await _loadColor(db, 'custom_text_secondary');

    _applyCustomColors();
    _syncIsLightMode();
    notifyListeners();
  }

  Future<Color?> _loadColor(DatabaseService db, String key) async {
    final val = await db.getSetting(key);
    if (val != null && val.isNotEmpty) {
      return Color(int.parse(val));
    }
    return null;
  }

  Future<void> _saveColor(String key, Color? color) async {
    final db = DatabaseService.instance;
    if (color != null) {
      await db.setSetting(key, color.value.toString());
    } else {
      await db.setSetting(key, '');
    }
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

  Future<void> setCustomBackground(Color? color) async {
    _customBackground = color;
    AppTheme.customBackground = color;
    await _saveColor('custom_bg', color);
    notifyListeners();
  }

  Future<void> setCustomSurface(Color? color) async {
    _customSurface = color;
    AppTheme.customSurface = color;
    await _saveColor('custom_surface', color);
    notifyListeners();
  }

  Future<void> setCustomCard(Color? color) async {
    _customCard = color;
    AppTheme.customCard = color;
    await _saveColor('custom_card', color);
    notifyListeners();
  }

  Future<void> setCustomTextPrimary(Color? color) async {
    _customTextPrimary = color;
    AppTheme.customTextPrimary = color;
    await _saveColor('custom_text_primary', color);
    notifyListeners();
  }

  Future<void> setCustomTextSecondary(Color? color) async {
    _customTextSecondary = color;
    AppTheme.customTextSecondary = color;
    await _saveColor('custom_text_secondary', color);
    notifyListeners();
  }

  Future<void> resetCustomColors() async {
    _customBackground = null;
    _customSurface = null;
    _customCard = null;
    _customTextPrimary = null;
    _customTextSecondary = null;
    AppTheme.customBackground = null;
    AppTheme.customSurface = null;
    AppTheme.customCard = null;
    AppTheme.customTextPrimary = null;
    AppTheme.customTextSecondary = null;
    final db = DatabaseService.instance;
    for (final key in ['custom_bg', 'custom_surface', 'custom_card', 'custom_text_primary', 'custom_text_secondary']) {
      await db.setSetting(key, '');
    }
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

  Color _bg() => _customBackground ?? AppTheme.lightBackground;
  Color _surface() => _customSurface ?? AppTheme.lightSurface;
  Color _card() => _customCard ?? AppTheme.lightCard;
  Color _textPrimary() => _customTextPrimary ?? const Color(0xFF1A1A1A);
  Color _textSecondary() => _customTextSecondary ?? const Color(0xFF666666);

  Color _darkBg() => _customBackground ?? AppTheme.darkBackground;
  Color _darkSurface() => _customSurface ?? AppTheme.darkSurface;
  Color _darkCard() => _customCard ?? AppTheme.darkCard;
  Color _darkTextPrimary() => _customTextPrimary ?? Colors.white;
  Color _darkTextSecondary() => _customTextSecondary ?? const Color(0xFFB3B3B3);

  ThemeData _buildLightTheme() {
    final bg = _bg();
    final surface = _surface();
    final card = _card();
    final textPri = _textPrimary();
    final textSec = _textSecondary();
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.light(
        primary: _accentColor,
        secondary: _accentColor,
        surface: surface,
        error: AppTheme.errorColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPri,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPri),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: textPri,
        unselectedItemColor: textSec,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: IconThemeData(color: textPri),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: textPri, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPri, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPri),
        bodyMedium: TextStyle(color: textSec),
        bodySmall: TextStyle(color: AppTheme.textTertiary),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFD0D0D0), thickness: 0.5),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accentColor,
        inactiveTrackColor: const Color(0xFFD0D0D0),
        thumbColor: textPri,
        overlayColor: _accentColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final bg = _darkBg();
    final surface = _darkSurface();
    final card = _darkCard();
    final textPri = _darkTextPrimary();
    final textSec = _darkTextSecondary();
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: _accentColor,
        secondary: _accentColor,
        surface: surface,
        error: AppTheme.errorColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPri,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPri),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: textPri,
        unselectedItemColor: textSec,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: IconThemeData(color: textPri),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: textPri, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPri, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPri),
        bodyMedium: TextStyle(color: textSec),
        bodySmall: TextStyle(color: AppTheme.textTertiary),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF404040), thickness: 0.5),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accentColor,
        inactiveTrackColor: const Color(0xFF404040),
        thumbColor: textPri,
        overlayColor: _accentColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }
}
