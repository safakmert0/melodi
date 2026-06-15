import 'package:flutter/material.dart';
import 'localization.dart';

export 'localization.dart' show AppLocale;

class AppConstants {
  static const String appName = 'Melodi';
  static const String appVersion = '1.0.0';

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
  static const Color primaryColor = Color(0xFF1DB954);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF282828);
  static const Color darkCardHover = Color(0xFF333333);
  static const Color darkDivider = Color(0xFF404040);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF727272);
  static const Color accentColor = Color(0xFF1DB954);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color favoriteColor = Color(0xFFE91E63);
  static const Color gradientStart = Color(0xFF1DB954);
  static const Color gradientEnd = Color(0xFF169C46);

  static const Color appleMusicRed = Color(0xFFFA233B);
  static const Color spotifyBlack = Color(0xFF191414);

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
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: textPrimary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textTertiary),
      ),
      dividerTheme: const DividerThemeData(color: darkDivider, thickness: 0.5),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: darkDivider,
        thumbColor: textPrimary,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }
}
