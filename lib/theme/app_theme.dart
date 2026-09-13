import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';
import 'spotify_colors.dart';

const int kDefaultSeedColor = 0xFF3A3A3C; // acik tema icin notr gri

/// Spotify DESIGN.md koyu semasi (docs/DESIGN.md).
const ColorScheme kSpotifyDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: SpotifyColors.green,
  onPrimary: Color(0xFF000000),
  primaryContainer: SpotifyColors.green,
  onPrimaryContainer: Color(0xFF000000),
  secondary: SpotifyColors.silver,
  onSecondary: SpotifyColors.nearBlack,
  secondaryContainer: SpotifyColors.midDark,
  onSecondaryContainer: SpotifyColors.white,
  tertiary: SpotifyColors.announcementBlue,
  onTertiary: SpotifyColors.white,
  error: SpotifyColors.negativeRed,
  onError: SpotifyColors.white,
  surface: SpotifyColors.nearBlack,
  onSurface: SpotifyColors.white,
  surfaceContainerLowest: SpotifyColors.nearBlack,
  surfaceContainerLow: SpotifyColors.darkSurface,
  surfaceContainer: SpotifyColors.midDark,
  surfaceContainerHigh: SpotifyColors.darkCard,
  surfaceContainerHighest: SpotifyColors.borderGray,
  onSurfaceVariant: SpotifyColors.silver,
  outline: SpotifyColors.borderGray,
  outlineVariant: SpotifyColors.lightBorder,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: SpotifyColors.white,
  onInverseSurface: SpotifyColors.nearBlack,
  inversePrimary: SpotifyColors.greenBorder,
  surfaceTint: Colors.transparent,
);

class AppTheme {
  static const Color defaultSeedColor = Color(kDefaultSeedColor);

  static const AppTokens _tokens = AppTokens.standard;

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      );

  static ThemeData light({ColorScheme? dynamicScheme, Color? seedColor}) {
    final scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor ?? defaultSeedColor,
          brightness: Brightness.light,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: _appBarTheme(scheme),
      cardTheme: _cardTheme(scheme),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      filledButtonTheme: _filledButtonTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(scheme),
      textButtonTheme: _textButtonTheme(scheme),
      floatingActionButtonTheme: _fabTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      listTileTheme: _listTileTheme(scheme),
      dialogTheme: _dialogTheme(scheme),
      bottomSheetTheme: _bottomSheetTheme,
      navigationBarTheme: _navigationBarTheme(scheme),
      snackBarTheme: _snackBarTheme(scheme),
      progressIndicatorTheme: _progressIndicatorTheme(scheme),
      switchTheme: _switchTheme(scheme),
      chipTheme: _chipTheme(scheme),
      dividerTheme: _dividerTheme(scheme),
      extensions: const <ThemeExtension<dynamic>>[AppTokens.standard],
      fontFamily: null, // sistem fontu — LA Player sade
    );
  }

  static ThemeData dark({
    ColorScheme? dynamicScheme,
    Color? seedColor,
    bool isAmoled = false,
  }) {
    // Spotify dili: sabit koyu sema (tohumdan turetilmez).
    final scheme = dynamicScheme ?? kSpotifyDarkScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      pageTransitionsTheme: _pageTransitionsTheme,
      scaffoldBackgroundColor: SpotifyColors.nearBlack,
      appBarTheme: _appBarTheme(scheme, isAmoled: isAmoled),
      cardTheme: _cardTheme(scheme),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      filledButtonTheme: _filledButtonTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(scheme),
      textButtonTheme: _textButtonTheme(scheme),
      floatingActionButtonTheme: _fabTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      listTileTheme: _listTileTheme(scheme),
      dialogTheme: _dialogTheme(scheme),
      bottomSheetTheme: _bottomSheetTheme,
      navigationBarTheme: _navigationBarTheme(scheme, isAmoled: isAmoled),
      snackBarTheme: _snackBarTheme(scheme),
      progressIndicatorTheme: _progressIndicatorTheme(scheme),
      switchTheme: _switchTheme(scheme),
      chipTheme: _chipTheme(scheme),
      dividerTheme: _dividerTheme(scheme),
      textTheme: _textTheme(scheme),
      extensions: const <ThemeExtension<dynamic>>[AppTokens.standard],
      fontFamily: null,
    );
  }

  /// Spotify tipografisi: 700/400 ikiligi, kompakt olcek.
  static TextTheme _textTheme(ColorScheme scheme) {
    const white = SpotifyColors.white;
    const silver = SpotifyColors.silver;
    return TextTheme(
      headlineSmall: const TextStyle(
          color: white, fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: const TextStyle(
          color: white, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(
          color: white, fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: const TextStyle(
          color: white, fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: const TextStyle(
          color: silver, fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: const TextStyle(
          color: silver, fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: const TextStyle(
          color: white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4),
    );
  }

  static AppBarTheme _appBarTheme(
    ColorScheme scheme, {
    bool isAmoled = false,
  }) =>
      AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: isAmoled ? 0 : 3,
        backgroundColor: isAmoled ? Colors.black : scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: isAmoled ? Colors.transparent : scheme.surfaceTint,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: scheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor:
              isAmoled ? Colors.black : scheme.surfaceContainer,
          systemNavigationBarIconBrightness: scheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      );

  static CardThemeData _cardTheme(ColorScheme scheme) => CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusControl),
        ),
        color: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: SpotifyColors.midDark,
          foregroundColor: SpotifyColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_tokens.radiusPill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      );

  static FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SpotifyColors.green,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_tokens.radiusPill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 43, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpotifyColors.white,
          side: const BorderSide(color: SpotifyColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_tokens.radiusPill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );

  static TextButtonThemeData _textButtonTheme(ColorScheme scheme) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_tokens.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );

  static FloatingActionButtonThemeData _fabTheme(ColorScheme scheme) =>
      const FloatingActionButtonThemeData(
        elevation: 6,
        shape: CircleBorder(),
        backgroundColor: SpotifyColors.green,
        foregroundColor: Colors.black,
      );

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) =>
      InputDecorationTheme(
        filled: true,
        fillColor: SpotifyColors.midDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusPill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusPill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusPill),
          borderSide: const BorderSide(color: SpotifyColors.white, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusControl),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      );

  static ListTileThemeData _listTileTheme(ColorScheme scheme) =>
      ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusControl),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );

  static final BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    constraints: const BoxConstraints(maxWidth: 640),
    shape: _tokens.sheetShape,
  );

  static DialogThemeData _dialogTheme(ColorScheme scheme) => DialogThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusSheet),
        ),
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: scheme.surfaceTint,
      );

  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme scheme, {
    bool isAmoled = false,
  }) =>
      NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isAmoled ? Colors.black : scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: isAmoled ? Colors.transparent : scheme.surfaceTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      );

  static SnackBarThemeData _snackBarTheme(ColorScheme scheme) => SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusThumb),
        ),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      );

  static ProgressIndicatorThemeData _progressIndicatorTheme(
    ColorScheme scheme,
  ) =>
      ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      );

  static SwitchThemeData _switchTheme(ColorScheme scheme) => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Icon(Icons.check, color: scheme.primary);
          }
          return null;
        }),
      );

  static ChipThemeData _chipTheme(ColorScheme scheme) => ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tokens.radiusCard),
        ),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
      );

  static DividerThemeData _dividerTheme(ColorScheme scheme) =>
      DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1);
}
