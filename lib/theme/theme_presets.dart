import 'package:flutter/material.dart';

/// WAVE uygulamasindan tasinan 6 hazir tema preset'i.
///
/// Her preset, [ThemeProvider] uzerindeki mevcut eksenlere eslenir:
/// tema modu + vurgu rengi + ozel arka plan/yuzey/kart/metin renkleri.
/// Yazi tipi ve kart sekli gibi WAVE'e ozgu eksenler tasinmaz.
class ThemePreset {
  final String id;
  final String name;
  final ThemeMode mode;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class ThemePresets {
  ThemePresets._();

  static const obsidian = ThemePreset(
    id: 'obsidian',
    name: 'Obsidian',
    mode: ThemeMode.dark,
    accent: Color(0xFFC9A84C),
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    card: Color(0xFF0D0D0D),
    textPrimary: Color(0xFFF5F0E8),
    textSecondary: Color(0xFF8A857D),
  );

  static const vapor = ThemePreset(
    id: 'vapor',
    name: 'Vapor',
    mode: ThemeMode.dark,
    accent: Color(0xFFFF6EFF),
    background: Color(0xFF0B0B1A),
    surface: Color(0xFF1A1A2E),
    card: Color(0xFF1A1A2E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
  );

  static const brutalist = ThemePreset(
    id: 'brutalist',
    name: 'Brutalist',
    mode: ThemeMode.light,
    accent: Color(0xFFFFE500),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF555555),
  );

  static const aurora = ThemePreset(
    id: 'aurora',
    name: 'Aurora',
    mode: ThemeMode.dark,
    accent: Color(0xFFE8A445),
    background: Color(0xFF0A1628),
    surface: Color(0xFF12233B),
    card: Color(0xFF12233B),
    textPrimary: Color(0xFFF5ECD7),
    textSecondary: Color(0xFF8FAF8F),
  );

  static const neonGrid = ThemePreset(
    id: 'neon_grid',
    name: 'Neon Grid',
    mode: ThemeMode.dark,
    accent: Color(0xFFFF0080),
    background: Color(0xFF080808),
    surface: Color(0xFF101018),
    card: Color(0xFF101018),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF808095),
  );

  static const minimalMono = ThemePreset(
    id: 'minimal_mono',
    name: 'Minimal Mono',
    mode: ThemeMode.light,
    accent: Color(0xFF1A1A1A),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFF5F5F5),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0x991A1A1A),
  );

  static const List<ThemePreset> all = <ThemePreset>[
    obsidian,
    vapor,
    brutalist,
    aurora,
    neonGrid,
    minimalMono,
  ];

  static ThemePreset? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
