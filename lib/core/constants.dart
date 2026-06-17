import 'package:flutter/material.dart';
import 'dart:ui' show Brightness;
import 'localization.dart';

export 'localization.dart' show AppLocale;

class AppConstants {
  static const String appName = 'Melodi';
  static const String appVersion = '1.9.1';
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
  static Color _accentColorValue = const Color(0xFF1DB954);
  static Color get primaryColor => _accentColorValue;
  static Color get accentColor => _accentColorValue;
  static Color get gradientStart => _accentColorValue;
  static Color get gradientEnd => _accentColorValue;
  static set accentColor(Color c) => _accentColorValue = c;

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

  // Text colors - dynamic + custom overrides
  static Color get textTertiary => isLightMode ? const Color(0xFF999999) : const Color(0xFF727272);

  // Background/surface colors - dynamic + custom overrides
  // Custom color overrides (null = use default)
  static Color? _customBackground;
  static Color? _customSurface;
  static Color? _customCard;
  static Color? _customTextPrimary;
  static Color? _customTextSecondary;

  static Color get background => _customBackground ?? (isLightMode ? lightBackground : darkBackground);
  static Color get surface => _customSurface ?? (isLightMode ? lightSurface : darkSurface);
  static Color get card => _customCard ?? (isLightMode ? lightCard : darkCard);
  static Color get cardHover => isLightMode ? lightCardHover : darkCardHover;
  static Color get divider => isLightMode ? lightDivider : darkDivider;

  static Color get textPrimary => _customTextPrimary ?? (isLightMode ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF));
  static Color get textSecondary => _customTextSecondary ?? (isLightMode ? const Color(0xFF666666) : const Color(0xFFB3B3B3));

  // Public setters for custom overrides (set null to use default)
  static set customBackground(Color? c) => _customBackground = c;
  static set customSurface(Color? c) => _customSurface = c;
  static set customCard(Color? c) => _customCard = c;
  static set customTextPrimary(Color? c) => _customTextPrimary = c;
  static set customTextSecondary(Color? c) => _customTextSecondary = c;

  static const Color errorColor = Color(0xFFE74C3C);
  static const Color favoriteColor = Color(0xFFE91E63);
  static const Color appleMusicRed = Color(0xFFFA233B);
  static const Color spotifyBlack = Color(0xFF191414);

}
