import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' show Brightness, ImageFilter;
import 'localization.dart';

export 'localization.dart' show AppLocale;

class AppConstants {
  static const String appName = 'Melodi';
  static const String appVersion = '3.0.0';
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

  static const double miniPlayerHeight = 60.0;
  static const double bottomNavHeight = 56.0;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDuration = Duration(milliseconds: 500);

  static const int maxRecentSearches = 20;
  static const int maxQueueHistory = 50;

  static const String fontFamily = 'BeVietnamPro';
}

class MelodiTheme {
  // Stitch Design System - Exact Colors
  static const Color background = Color(0xFF121414);
  static const Color surface = Color(0xFF121414);
  static const Color surfaceBright = Color(0xFF37393A);
  static const Color surfaceLowest = Color(0xFF0C0F0F);
  static const Color containerLow = Color(0xFF1A1C1C);
  static const Color container = Color(0xFF1E2020);
  static const Color containerHigh = Color(0xFF282A2B);
  static const Color containerHighest = Color(0xFF333535);

  static const Color onSurface = Color(0xFFE2E2E2);
  static const Color onSurfaceVariant = Color(0xFFBCCBB9);

  // Primary - Emerald
  static const Color primaryGreen = Color(0xFF53E076);
  static const Color primaryGreenBright = Color(0xFF72FE8F);
  static const Color primaryContainer = Color(0xFF1DB954);
  static const Color onPrimary = Color(0xFF003914);
  static const Color onPrimaryContainer = Color(0xFF004118);

  // Secondary
  static const Color secondary = Color(0xFFC8C6C5);
  static const Color secondaryContainer = Color(0xFF4A4949);
  static const Color onSecondaryContainer = Color(0xFFBAB8B7);

  // Outline
  static const Color outline = Color(0xFF869585);
  static const Color outlineVariant = Color(0xFF3D4A3D);

  // Error
  static const Color errorRed = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Glass
  static const Color glassBorder = Color(0x15FFFFFF);

  // Liked Songs Gradient
  static const Color likedGradientStart = Color(0xFF450AF5);
  static const Color likedGradientEnd = Color(0xFFC4EFD9);

  // Backward compatibility
  static Color get textPrimary => onSurface;
  static Color get textSecondary => onSurfaceVariant;
  static Color get textMuted => const Color(0xFF869585);

  // Additional surface colors
  static const Color surfaceMid2 = container;
  static const Color surfaceMid1 = containerLow;
  static const Color surfaceHigh = containerHighest;

  // Genre Colors (from Stitch)
  static const Map<String, Color> genreColors = {
    'pop': Color(0xFF8D67AB),
    'rock': Color(0xFFE8115B),
    'hip_hop': Color(0xFFBC462B),
    'jazz': Color(0xFF1E3264),
    'electronic': Color(0xFF006450),
    'classical': Color(0xFF7358FF),
    'rnb': Color(0xFFD84000),
    'indie': Color(0xFFE91429),
  };

  // Typography - Be Vietnam Pro
  static TextStyle display({double size = 48, FontWeight weight = FontWeight.w800}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: onSurface,
      letterSpacing: -0.02 * size,
    );
  }

  static TextStyle heading({double size = 28, FontWeight weight = FontWeight.w700}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: onSurface,
      letterSpacing: -0.01 * size,
    );
  }

  static TextStyle title({double size = 20, FontWeight weight = FontWeight.w600}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: onSurface,
    );
  }

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurface,
      height: 1.5,
    );
  }

  static TextStyle bodySm({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurface,
      height: 1.4,
    );
  }

  static TextStyle label({double size = 12, FontWeight weight = FontWeight.w700, Color? color, double letterSpacing = 0.05}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurfaceVariant,
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }

  static TextStyle labelSm({double size = 13, FontWeight weight = FontWeight.w500, Color? color}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurfaceVariant,
      height: 1.4,
    );
  }

  // Glassmorphism Helpers
  static BoxDecoration glassDecoration({double radius = 8, double opacity = 0.6}) {
    return BoxDecoration(
      color: background.withOpacity( opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder, width: 0.5),
    );
  }

  static Widget glassContainer({
    required Widget child,
    double sigmaX = 20,
    double sigmaY = 20,
    double opacity = 0.6,
    double radius = 8,
    EdgeInsets? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: background.withOpacity( opacity),
            border: Border.all(color: glassBorder, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }

  // Theme
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: AppConstants.fontFamily,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: secondary,
        surface: background,
        error: errorRed,
        surfaceContainerLow: containerLow,
        surfaceContainer: container,
        surfaceContainerHigh: containerHigh,
        surfaceContainerHighest: containerHighest,
      ),
      cardColor: containerLow,
      dividerColor: outlineVariant,
      iconTheme: const IconThemeData(color: onSurfaceVariant),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.22,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: primaryGreen,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 11),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryGreen,
        inactiveTrackColor: surfaceBright,
        thumbColor: primaryGreen,
        overlayColor: Color(0x3353E076),
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryGreen;
          return onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryGreen.withOpacity(0.3);
          return surfaceBright;
        }),
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

// Backward compatibility for theme_provider.dart
class AppTheme {
  static bool isLightMode = false;
  static Color accentColor = MelodiTheme.primaryGreen;
  static Color? customBackground;
  static Color? customSurface;
  static Color? customCard;
  static Color? customTextPrimary;
  static Color? customTextSecondary;

  static Color get background => customBackground ?? (isLightMode ? const Color(0xFFF5F5F5) : MelodiTheme.background);
  static Color get surface => customSurface ?? (isLightMode ? const Color(0xFFFFFFFF) : MelodiTheme.containerLow);
  static Color get card => customCard ?? (isLightMode ? const Color(0xFFEEEEEE) : MelodiTheme.containerLow);
  static Color get textPrimary => customTextPrimary ?? (isLightMode ? const Color(0xFF1A1A1A) : MelodiTheme.onSurface);
  static Color get textSecondary => customTextSecondary ?? (isLightMode ? const Color(0xFF666666) : MelodiTheme.onSurfaceVariant);
  static Color get textTertiary => isLightMode ? const Color(0xFF999999) : MelodiTheme.textMuted;
  static Color get primaryColor => accentColor;
  static Color get errorColor => MelodiTheme.errorRed;
  static Color get favoriteColor => MelodiTheme.primaryGreen;
  static Color get divider => MelodiTheme.outlineVariant;
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEEEEE);
  static const Color darkBackground = MelodiTheme.background;
  static const Color darkSurface = MelodiTheme.containerLow;
  static const Color darkCard = MelodiTheme.containerLow;
}
