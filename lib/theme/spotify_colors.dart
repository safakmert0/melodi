import 'package:flutter/material.dart';

/// Spotify DESIGN.md renkleri (docs/DESIGN.md tek dogruluk kaynagidir).
/// Yesil yalnizca islevsel vurguda kullanilir (cal, aktif, CTA).
class SpotifyColors {
  SpotifyColors._();

  static const Color green = Color(0xFF1ED760);
  static const Color greenBorder = Color(0xFF1DB954);

  static const Color nearBlack = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF181818);
  static const Color midDark = Color(0xFF1F1F1F);
  static const Color darkCard = Color(0xFF252525);

  static const Color white = Color(0xFFFFFFFF);
  static const Color silver = Color(0xFFB3B3B3);
  static const Color nearWhite = Color(0xFFCBCBCB);

  static const Color negativeRed = Color(0xFFF3727F);
  static const Color warningOrange = Color(0xFFFFA42B);
  static const Color announcementBlue = Color(0xFF539DF5);

  static const Color borderGray = Color(0xFF4D4D4D);
  static const Color lightBorder = Color(0xFF7C7C7C);

  /// Koyu zeminde gorunur agir golge (karti yukseltilmis gosterir).
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 8,
          offset: Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get dialogShadow => const [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];

  /// Yesil dairesel cal butonu dekoru.
  static BoxDecoration get greenPlayCircle => const BoxDecoration(
        color: green,
        shape: BoxShape.circle,
      );

  /// Hap buton dekoru (koyu).
  static BoxDecoration get darkPill => BoxDecoration(
        color: midDark,
        borderRadius: BorderRadius.circular(9999),
      );

  /// Cerceveli hap buton dekoru.
  static BoxDecoration get outlinedPill => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: lightBorder),
      );
}
