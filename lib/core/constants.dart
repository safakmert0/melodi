import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' show Brightness, ImageFilter;
export 'localization.dart' show AppLocale;

class AppConstants {
  static const String appName = 'Melodi';
  static const String appVersion = '4.2.0';
  static const String buildNumber = '7';

  static const List<String> supportedAudioExtensions = [
    'mp3',
    'm4a',
    'flac',
    'wav',
    'aac',
    'ogg',
    'wma',
    'alac',
    'aiff',
    'opus',
    'ape',
    'wv',
    'mid',
    'midi',
  ];

  static const List<String> supportedMimeTypes = [
    'audio/mpeg',
    'audio/mp4',
    'audio/flac',
    'audio/wav',
    'audio/aac',
    'audio/ogg',
    'audio/x-ms-wma',
    'audio/x-alac',
    'audio/x-aiff',
    'audio/opus',
    'audio/x-ape',
    'audio/x-wavpack',
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
  // Melodi Spectrum — ink surfaces with a warm, musical brand accent.
  // These compatibility colors intentionally resolve at runtime. A large
  // number of mature feature screens predate ColorScheme; keeping the legacy
  // API dynamic makes those screens immediately safe in light mode too.
  static Color get background =>
      AppTheme.isLightMode ? const Color(0xFFF8F5F8) : const Color(0xFF08080C);
  static Color get surface =>
      AppTheme.isLightMode ? const Color(0xFFFFFFFF) : const Color(0xFF08080C);
  static Color get surfaceBright =>
      AppTheme.isLightMode ? const Color(0xFFFFFFFF) : const Color(0xFF34313D);
  static Color get surfaceLowest =>
      AppTheme.isLightMode ? const Color(0xFFFFFBFF) : const Color(0xFF050507);
  static Color get containerLow =>
      AppTheme.isLightMode ? const Color(0xFFF2EDF2) : const Color(0xFF101016);
  static Color get container =>
      AppTheme.isLightMode ? const Color(0xFFEBE4EC) : const Color(0xFF16151E);
  static Color get containerHigh =>
      AppTheme.isLightMode ? const Color(0xFFE3DAE5) : const Color(0xFF201E2A);
  static Color get containerHighest =>
      AppTheme.isLightMode ? const Color(0xFFD8CDD9) : const Color(0xFF2B2836);

  static Color get onSurface =>
      AppTheme.isLightMode ? const Color(0xFF211B20) : const Color(0xFFF8F4F7);
  static Color get onSurfaceVariant =>
      AppTheme.isLightMode ? const Color(0xFF645B64) : const Color(0xFFC9C1CB);

  // Kept under the legacy name so existing feature screens inherit the new
  // brand without a risky, all-at-once API rename.
  static const Color primaryGreen = Color(0xFFFF4D8D);
  static const Color primaryGreenBright = Color(0xFFFF79AA);
  static const Color primaryContainer = Color(0xFF5E1638);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFD8E7);

  // Secondary
  static const Color secondary = Color(0xFFC8C6C5);
  static const Color secondaryContainer = Color(0xFF4A4949);
  static const Color onSecondaryContainer = Color(0xFFBAB8B7);

  // Outline
  static Color get outline =>
      AppTheme.isLightMode ? const Color(0xFF81747F) : const Color(0xFF8F8492);
  static Color get outlineVariant =>
      AppTheme.isLightMode ? const Color(0xFFD7CCD7) : const Color(0xFF3B3540);

  // Error
  static Color get errorRed =>
      AppTheme.isLightMode ? const Color(0xFFB3261E) : const Color(0xFFFFB4AB);
  static Color get errorContainer =>
      AppTheme.isLightMode ? const Color(0xFFFFDAD6) : const Color(0xFF93000A);
  static Color get onErrorContainer =>
      AppTheme.isLightMode ? const Color(0xFF410002) : const Color(0xFFFFDAD6);

  // Glass
  static const Color glassBorder = Color(0x15FFFFFF);

  // Liked Songs Gradient
  static const Color likedGradientStart = Color(0xFF450AF5);
  static const Color likedGradientEnd = Color(0xFFC4EFD9);

  // Backward compatibility
  static Color get textPrimary => onSurface;
  static Color get textSecondary => onSurfaceVariant;
  static Color get textMuted =>
      AppTheme.isLightMode ? const Color(0xFF766C76) : const Color(0xFF958B99);

  // Additional surface colors
  static Color get surfaceMid2 => container;
  static Color get surfaceMid1 => containerLow;
  static Color get surfaceHigh => containerHighest;

  // Genre Colors (from Stitch)
  static const Map<String, Color> genreColors = {
    'pop': Color(0xFF8D67AB),
    'rock': Color(0xFFE8115B),
    'hip_hop': Color(0xFFBC462B),
    'jazz': Color(0xFF1E3264),
    'electronic': Color(0xFF2196F3),
    'classical': Color(0xFF7358FF),
    'rnb': Color(0xFFD84000),
    'indie': Color(0xFFE91429),
  };

  // Typography - Be Vietnam Pro (Profesyonel boyutlar)
  static TextStyle display(
      {double size = 52, FontWeight weight = FontWeight.w800}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: onSurface,
      letterSpacing: -0.02 * size,
    );
  }

  static TextStyle heading(
      {double size = 32, FontWeight weight = FontWeight.w700}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: onSurface,
      letterSpacing: -0.01 * size,
    );
  }

  static TextStyle title(
      {double size = 22, FontWeight weight = FontWeight.w600}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: onSurface,
    );
  }

  static TextStyle body(
      {double size = 17, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurface,
      height: 1.5,
    );
  }

  static TextStyle bodySm(
      {double size = 15, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurface,
      height: 1.4,
    );
  }

  static TextStyle label(
      {double size = 13,
      FontWeight weight = FontWeight.w700,
      Color? color,
      double letterSpacing = 0.04}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurfaceVariant,
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }

  static TextStyle labelSm(
      {double size = 14, FontWeight weight = FontWeight.w500, Color? color}) {
    return TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? onSurfaceVariant,
      height: 1.4,
    );
  }

  // Glassmorphism Helpers
  static BoxDecoration glassDecoration(
      {double radius = 8, double opacity = 0.6}) {
    return BoxDecoration(
      color: background .withOpacity(opacity),
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
            color: background .withOpacity(opacity),
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
      colorScheme: ColorScheme.dark(
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
      iconTheme: IconThemeData(color: onSurfaceVariant),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.24,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: primaryGreen,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
            fontFamily: AppConstants.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 12),
      ),
      sliderTheme: SliderThemeData(
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
          if (states.contains(WidgetState.selected)) {
            return primaryGreen .withOpacity(0.3);
          }
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

  static Color get background =>
      customBackground ??
      (isLightMode ? const Color(0xFFF5F5F5) : MelodiTheme.background);
  static Color get surface =>
      customSurface ??
      (isLightMode ? const Color(0xFFFFFFFF) : MelodiTheme.containerLow);
  static Color get card =>
      customCard ??
      (isLightMode ? const Color(0xFFEEEEEE) : MelodiTheme.containerLow);
  static Color get textPrimary =>
      customTextPrimary ??
      (isLightMode ? const Color(0xFF1A1A1A) : MelodiTheme.onSurface);
  static Color get textSecondary =>
      customTextSecondary ??
      (isLightMode ? const Color(0xFF666666) : MelodiTheme.onSurfaceVariant);
  static Color get textTertiary =>
      isLightMode ? const Color(0xFF999999) : MelodiTheme.textMuted;
  static Color get primaryColor => accentColor;
  static Color get errorColor => MelodiTheme.errorRed;
  static Color get favoriteColor => MelodiTheme.primaryGreen;
  static Color get divider => MelodiTheme.outlineVariant;
  static const Color lightBackground = Color(0xFFF8F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0EAF0);
  static const Color darkBackground = Color(0xFF08080C);
  static const Color darkSurface = Color(0xFF101016);
  static const Color darkCard = Color(0xFF101016);
}
