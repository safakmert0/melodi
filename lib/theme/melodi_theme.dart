import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

/// Melodi Theme — YouTube Music inspired Material 3 theme
class MelodiTheme {
  // YouTube Music Red
  static const Color ytRed = Color(0xFFFF0000);
  static const Color ytRedLight = Color(0xFFFF4444);
  static const Color ytRedDark = Color(0xFFCC0000);

  // Carbon / Dark backgrounds
  static const Color carbon = Color(0xFF0F0F0F);
  static const Color carbonElevated = Color(0xFF1A1A1A);
  static const Color carbonOverlay = Color(0xFF242424);

  // Light theme equivalents
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);
  static const Color lightBackground = Color(0xFFFFFFFF);

  // Semantic colors
  static const Color primary = ytRed;
  static const Color onPrimary = white;
  static const Color primaryContainer = ytRedLight;
  static const Color onPrimaryContainer = white;

  static const Color secondary = Color(0xFF666666);
  static const Color onSecondary = white;
  static const Color secondaryContainer = Color(0xFF333333);
  static const Color onSecondaryContainer = white;

  static const Color tertiary = Color(0xFF00B0FF);
  static const Color onTertiary = white;
  static const Color tertiaryContainer = Color(0xFFE0F7FF);
  static const Color onTertiaryContainer = Color(0xFF001F33);

  // Surface colors
  static const Color surface = carbon;
  static const Color onSurface = white;
  static const Color surfaceVariant = carbonElevated;
  static const Color onSurfaceVariant = Color(0xFFB3B3B3);
  static const Color surfaceContainer = carbonElevated;
  static const Color surfaceContainerHigh = carbonOverlay;
  static const Color surfaceContainerHighest = Color(0xFF2C2C2C);

  // Background
  static const Color background = carbon;
  static const Color onBackground = white;

  // Outline
  static const Color outline = Color(0xFF333333);
  static const Color outlineVariant = Color(0xFF444444);

  // Error
  static const Color error = Color(0xFFFF4444);
  static const Color onError = white;
  static const Color errorContainer = Color(0xFF330000);
  static const Color onErrorContainer = white;

  // Inverse
  static const Color inverseSurface = lightSurface;
  static const Color inverseOnSurface = carbon;
  static const Color inversePrimary = ytRedDark;

  // Shadow
  static const Color shadow = Color(0x00000000);
  static const Color scrim = Color(0x80000000);

  // Light theme surface colors
  static const Color lightOnSurface = carbon;
  static const Color lightOnSurfaceVariant = Color(0xFF666666);
  static const Color lightSurfaceContainer = Color(0xFFF5F5F5);
  static const Color lightSurfaceContainerHigh = Color(0xFFEEEEEE);
  static const Color lightOutline = Color(0xFFCCCCCC);
  static const Color lightOutlineVariant = Color(0xFFDDDDDD);

  /// Dark color scheme (YouTube Music dark)
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    background: background,
    onBackground: onBackground,
    surface: surface,
    onSurface: onSurface,
    surfaceVariant: surfaceVariant,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: shadow,
    scrim: scrim,
    inverseSurface: inverseSurface,
    onInverseSurface: inverseOnSurface,
    inversePrimary: inversePrimary,
  );

  /// Light color scheme (for system light mode)
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: ytRed,
    onPrimary: white,
    primaryContainer: Color(0xFFFFEBEE),
    onPrimaryContainer: ytRedDark,
    secondary: Color(0xFF666666),
    onSecondary: white,
    secondaryContainer: Color(0xFFF5F5F5),
    onSecondaryContainer: carbon,
    tertiary: Color(0xFF0066CC),
    onTertiary: white,
    tertiaryContainer: Color(0xFFE0F7FF),
    onTertiaryContainer: Color(0xFF001F33),
    error: error,
    onError: white,
    errorContainer: Color(0xFFFFEBEE),
    onErrorContainer: ytRedDark,
    background: lightBackground,
    onBackground: lightOnSurface,
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceVariant: lightSurfaceVariant,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
    outlineVariant: lightOutlineVariant,
    shadow: shadow,
    scrim: scrim,
    inverseSurface: surface,
    onInverseSurface: onSurface,
    inversePrimary: ytRedLight,
  );

  /// Theme data for dark mode (default)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: carbon,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceVariant,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineVariant),
      ),
      shadowColor: shadow,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: carbon,
      selectedItemColor: ytRed,
      unselectedItemColor: onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: carbon,
      indicatorColor: primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: ytRed, fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: onSurfaceVariant, fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: ytRed, size: 24);
        }
        return const IconThemeData(color: onSurfaceVariant, size: 24);
      }),
      height: 72,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: ytRed,
      inactiveTrackColor: outlineVariant,
      thumbColor: ytRed,
      overlayColor: Color(0x33FF0000),
      trackHeight: 4,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ytRed,
      linearTrackColor: outlineVariant,
      circularTrackColor: outlineVariant,
    ),
    iconTheme: const IconThemeData(color: white),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: white, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: white, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(color: white, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: white, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: white, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: white, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: white, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: white, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(color: white, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(color: white, fontSize: 16),
      bodyMedium: TextStyle(color: white, fontSize: 14),
      bodySmall: TextStyle(color: onSurfaceVariant, fontSize: 12),
      labelLarge: TextStyle(color: white, fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: TextStyle(color: onSurfaceVariant, fontSize: 12),
      labelSmall: TextStyle(color: onSurfaceVariant, fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ytRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: onSurfaceVariant),
      labelStyle: const TextStyle(color: onSurfaceVariant),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: carbon,
      modalBackgroundColor: carbon,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: carbonElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: white, fontSize: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: carbonOverlay,
      contentTextStyle: const TextStyle(color: white),
      actionTextColor: ytRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      selectedColor: primaryContainer,
      labelStyle: const TextStyle(color: white),
      secondaryLabelStyle: const TextStyle(color: white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: white,
      textColor: white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ytRed,
      foregroundColor: white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ytRed;
          return carbonElevated;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          return white;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BorderSide.none;
          return BorderSide(color: outlineVariant);
        }),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ytRed,
      unselectedLabelColor: onSurfaceVariant,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: ytRed, width: 3),
        insets: EdgeInsets.symmetric(horizontal: 16),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    ),
    extensions: <ThemeExtension<dynamic>>[],
  );

  /// Light theme (for system light mode)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: carbon,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: carbon,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: lightOutlineVariant),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: ytRed,
      unselectedItemColor: lightOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: Color(0xFFFFEBEE),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: ytRed, fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: lightOnSurfaceVariant, fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: ytRed, size: 24);
        }
        return const IconThemeData(color: lightOnSurfaceVariant, size: 24);
      }),
      height: 72,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: ytRed,
      inactiveTrackColor: lightOutlineVariant,
      thumbColor: ytRed,
      overlayColor: Color(0x33FF0000),
      trackHeight: 4,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: ytRed),
    iconTheme: const IconThemeData(color: carbon),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: carbon, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: carbon, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(color: carbon, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: carbon, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: carbon, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: carbon, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: carbon, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: carbon, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(color: carbon, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(color: carbon, fontSize: 16),
      bodyMedium: TextStyle(color: carbon, fontSize: 14),
      bodySmall: TextStyle(color: lightOnSurfaceVariant, fontSize: 12),
      labelLarge: TextStyle(color: carbon, fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: TextStyle(color: lightOnSurfaceVariant, fontSize: 12),
      labelSmall: TextStyle(color: lightOnSurfaceVariant, fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightOutlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ytRed, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      modalBackgroundColor: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(color: carbon, fontSize: 20, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: carbon, fontSize: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: carbonElevated,
      contentTextStyle: const TextStyle(color: white),
      actionTextColor: ytRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightSurfaceVariant,
      selectedColor: Color(0xFFFFEBEE),
      labelStyle: const TextStyle(color: carbon),
      secondaryLabelStyle: const TextStyle(color: carbon),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: lightOutlineVariant, thickness: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: carbon,
      textColor: carbon,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ytRed,
      foregroundColor: white,
    ),
  );

  /// Create theme with dynamic color support (Material You)
  static Widget themeWithDynamicColor({
    required Widget child,
    required ThemeData lightTheme,
    required ThemeData darkTheme,
  }) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          theme: lightTheme.copyWith(
            colorScheme: lightDynamic ?? lightColorScheme,
          ),
          darkTheme: darkTheme.copyWith(
            colorScheme: darkDynamic ?? darkColorScheme,
          ),
          themeMode: ThemeMode.system,
          home: child,
        );
      },
    );
  }
}

/// Extension for easy access to theme colors
extension MelodiColors on BuildContext {
  Color get ytRed => MelodiTheme.ytRed;
  Color get carbon => MelodiTheme.carbon;
  Color get carbonElevated => MelodiTheme.carbonElevated;
  Color get onSurfaceVariant => MelodiTheme.onSurfaceVariant;
  Color get outlineVariant => MelodiTheme.outlineVariant;
}