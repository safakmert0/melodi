import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart' as spotiflac_theme;

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  ThemeMode _themeMode = ThemeMode.dark;
  static const Color _melodiAccent = Color(0xFF1DB954);
  static const int _legacyBlue = 0xFF2196F3;
  Color _accentColor = _melodiAccent;
  Color? _customBackground;
  Color? _customSurface;
  Color? _customCard;
  Color? _customTextPrimary;
  Color? _customTextSecondary;
  bool _useDynamicColor = true;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  Color? get customBackground => _customBackground;
  Color? get customSurface => _customSurface;
  Color? get customCard => _customCard;
  Color? get customTextPrimary => _customTextPrimary;
  Color? get customTextSecondary => _customTextSecondary;
  bool get useDynamicColor => _useDynamicColor;

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
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
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
    try {
      final db = DatabaseService.instance;
      final mode = await db.getSetting('theme_mode');
      if (mode != null) {
        final index = int.tryParse(mode);
        if (index != null && index >= 0 && index < ThemeMode.values.length) {
          _themeMode = ThemeMode.values[index];
        }
      }
      final dynamicColorStr = await db.getSetting('use_dynamic_color');
      if (dynamicColorStr != null) {
        _useDynamicColor = dynamicColorStr == 'true';
      }
      final colorStr = await db.getSetting('accent_color');
      if (colorStr != null && colorStr.isNotEmpty) {
        final val = int.tryParse(colorStr);
        if (val == _legacyBlue) {
          _accentColor = _melodiAccent;
          await db.setSetting(
            'accent_color',
            _melodiAccent.value.toString(),
          );
        } else if (val != null) {
          _accentColor = Color(val);
        }
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
    } catch (_) {}
  }

  Future<Color?> _loadColor(DatabaseService db, String key) async {
    try {
      final val = await db.getSetting(key);
      if (val != null && val.isNotEmpty) {
        final parsed = int.tryParse(val);
        if (parsed != null) return Color(parsed);
      }
    } catch (_) {}
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
    notifyListeners();
    await DatabaseService.instance
        .setSetting('theme_mode', mode.index.toString());
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode != ThemeMode.system) return;
    _syncIsLightMode();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> setUseDynamicColor(bool value) async {
    _useDynamicColor = value;
    await DatabaseService.instance
        .setSetting('use_dynamic_color', value.toString());
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    AppTheme.accentColor = color;
    await DatabaseService.instance
        .setSetting('accent_color', color.value.toString());
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
    for (final key in [
      'custom_bg',
      'custom_surface',
      'custom_card',
      'custom_text_primary',
      'custom_text_secondary'
    ]) {
      await db.setSetting(key, '');
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
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
    await DatabaseService.instance
        .setSetting('theme_mode', _themeMode.index.toString());
    notifyListeners();
  }

  // SpotiFLAC 1:1 theming — delegate to AppTheme so the design is identical.
  ThemeData get lightTheme => spotiflac_theme.AppTheme.light(seedColor: _accentColor);
  ThemeData get darkTheme => spotiflac_theme.AppTheme.dark(seedColor: _accentColor, isAmoled: false);

  ThemeData get currentTheme {
    switch (_themeMode) {
      case ThemeMode.light:
        return lightTheme;
      case ThemeMode.dark:
        return darkTheme;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.light
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

  ThemeData _buildLightTheme() => lightTheme;
  ThemeData _buildDarkTheme() => darkTheme;

  ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final dark = brightness == Brightness.dark;
    final onAccent =
        _accentColor.computeLuminance() > 0.52 ? Colors.black : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: _accentColor,
      onPrimary: onAccent,
      secondary: const Color(0xFF8C72FF),
      tertiary: dark ? const Color(0xFF42DCC8) : const Color(0xFF007F73),
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: dark ? const Color(0xFF6F6574) : const Color(0xFF8C818E),
      outlineVariant: dark ? const Color(0xFF39323F) : const Color(0xFFE1D8E2),
      error: AppTheme.errorColor,
    );
    final typography = TextTheme(
      displayLarge: TextStyle(
        color: textPrimary,
        fontSize: 52,
        height: 0.98,
        letterSpacing: -2.4,
        fontWeight: FontWeight.w900,
      ),
      headlineLarge: TextStyle(
        color: textPrimary,
        fontSize: 34,
        letterSpacing: -1.3,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 27,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: TextStyle(
        color: textPrimary,
        fontSize: 22,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: textPrimary, height: 1.35),
      bodyMedium: TextStyle(color: textSecondary, height: 1.35),
      bodySmall: TextStyle(color: textSecondary, height: 1.3),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
    ).apply(fontFamily: AppConstants.fontFamily);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppConstants.fontFamily,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: typography,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: card .withOpacity(0.82),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant .withOpacity(0.5)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card .withOpacity(0.82),
        selectedColor: _accentColor .withOpacity(0.2),
        side: BorderSide(color: scheme.outlineVariant .withOpacity(0.55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: typography.labelMedium,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor:
            WidgetStatePropertyAll(card .withOpacity(dark ? 0.88 : 1)),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant .withOpacity(0.65)),
        ),
        shape: WidgetStatePropertyAll(controlShape),
        textStyle: WidgetStatePropertyAll(typography.bodyLarge),
        hintStyle: WidgetStatePropertyAll(
          typography.bodyMedium?.copyWith(color: textSecondary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card .withOpacity(dark ? 0.88 : 1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
          textStyle: typography.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: const CircleBorder()),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant .withOpacity(0.6),
        thickness: 0.6,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accentColor,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: textPrimary,
        overlayColor: _accentColor .withOpacity(0.18),
        trackHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? _accentColor : card),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
