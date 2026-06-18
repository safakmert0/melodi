import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:http/http.dart' as http;

class ColorPalette {
  final Color dominant;
  final Color? vibrant;
  final Color? darkVibrant;
  final Color? lightVibrant;
  final Color? muted;
  final Color? darkMuted;
  final Color? lightMuted;

  ColorPalette({
    required this.dominant,
    this.vibrant,
    this.darkVibrant,
    this.lightVibrant,
    this.muted,
    this.darkMuted,
    this.lightMuted,
  });

  factory ColorPalette.fromPaletteGenerator(PaletteGenerator palette) {
    return ColorPalette(
      dominant: palette.dominantColor?.color ?? Colors.grey,
      vibrant: palette.vibrantColor?.color,
      darkVibrant: palette.darkVibrantColor?.color,
      lightVibrant: palette.lightVibrantColor?.color,
      muted: palette.mutedColor?.color,
      darkMuted: palette.darkMutedColor?.color,
      lightMuted: palette.lightMutedColor?.color,
    );
  }
}

class ColorExtractor {
  static final Map<String, Color> _colorCache = {};
  static final Map<String, ColorPalette> _paletteCache = {};

  static Future<ColorPalette> extractColors(Uint8List imageData) async {
    final palette = await PaletteGenerator.fromImageProvider(
      MemoryImage(imageData),
      maximumColorCount: 8,
    );
    return ColorPalette.fromPaletteGenerator(palette);
  }

  static Future<ColorPalette> extractColorsFromUrl(String imageUrl) async {
    if (_paletteCache.containsKey(imageUrl)) {
      return _paletteCache[imageUrl]!;
    }
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        final palette = await extractColors(data);
        _paletteCache[imageUrl] = palette;
        return palette;
      }
    } catch (_) {}
    return ColorPalette(dominant: Colors.grey);
  }

  static Future<Color> getDominantColor(Uint8List imageData) async {
    final palette = await extractColors(imageData);
    return palette.dominant;
  }

  static Future<List<Color>> getBackgroundColors(Uint8List imageData) async {
    final palette = await extractColors(imageData);
    final darkVariant = palette.darkVibrant ?? palette.darkMuted ?? palette.dominant;
    final lightVariant = palette.lightVibrant ?? palette.lightMuted ?? palette.dominant;
    return [darkVariant, lightVariant];
  }

  static bool isDark(Color color) {
    return color.computeLuminance() < 0.5;
  }

  static void clearCache() {
    _colorCache.clear();
    _paletteCache.clear();
  }
}
