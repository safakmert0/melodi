import 'package:flutter/material.dart';
import 'dart:ui' show Brightness;
import 'localization.dart';

export 'localization.dart' show AppLocale;

class AppConstants {
  static const String appName = 'Melodi';
  static const String appVersion = '1.6.0';
  static const String buildNumber = '1';

  static const List<String> supportedAudioExtensions = [
    'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma',
    'alac', 'aiff', 'opus', 'ape', 'wv', 'mid', 'midi',
  ];

  static const List<String> supportedMimeTypes = [
    'audio/mpeg', 'audio/mp4', 'audio/flac', 'audio/wav',
    'audio/aac', 'audio/ogg', 'audio/x-ms-wma',
    'audio/x-alac', 'audio/x-aiff', 'audio/opus',
    'audio/x-ape', 'audio/x-wavpack',
  ];

  static const Duration seekStep = Duration(seconds: 10);
  static const Duration fastForwardStep = Duration(seconds: 30);

  static const double miniPlayerHeight = 64.0;
  static const double bottomNavHeight = 56.0;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDuration = Duration(milliseconds: 500);

  static const int maxRecentSearches = 20;
  static const int maxQueueHistory = 50;
}

class AppTheme {
  static bool isLightMode = false;

  // Dark theme colors
  static const Color primaryColor = Color(0xFF1DB954);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF282828);
  static const Color darkCardHover = Color(0xFF333333);
  static const Color darkDivider = Color(0xFF404040);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEEEEE);
  static const Color lightCardHover = Color(0xFFE0E0E0);
  static const Color lightDivider = Color(0xFFD0D0D0);

  // Text colors - dynamic based on isLightMode
  static Color get textPrimary => isLightMode ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  static Color get textSecondary => isLightMode ? const Color(0xFF666666) : const Color(0xFFB3B3B3);
  static Color get textTertiary => isLightMode ? const Color(0xFF999999) : const Color(0xFF727272);

  // Background/surface colors - dynamic based on isLightMode
  static Color get background => isLightMode ? lightBackground : darkBackground;
  static Color get surface => isLightMode ? lightSurface : darkSurface;
  static Color get card => isLightMode ? lightCard : darkCard;
  static Color get cardHover => isLightMode ? lightCardHover : darkCardHover;
  static Color get divider => isLightMode ? lightDivider : darkDivider;

  static const Color accentColor = Color(0xFF1DB954);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color favoriteColor = Color(0xFFE91E63);
  static const Color gradientStart = Color(0xFF1DB954);
  static const Color gradientEnd = Color(0xFF169C46);
  static const Color appleMusicRed = Color(0xFFFA233B);
  static const Color spotifyBlack = Color(0xFF191414);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: lightSurface,
        error: errorColor,
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
        activeTrackColor: primaryColor,
        inactiveTrackColor: const Color(0xFFD0D0D0),
        thumbColor: const Color(0xFF1A1A1A),
        overlayColor: primaryColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: darkSurface,
        error: errorColor,
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
        activeTrackColor: primaryColor,
        inactiveTrackColor: const Color(0xFF404040),
        thumbColor: Colors.white,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }
}
