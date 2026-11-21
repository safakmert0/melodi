import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Lyrics resolver with fallback chain: LRCLib → Kugou → Kizzy
/// InnerTune pattern: try each source in order, return first success
class LyricsResolver {
  static final LyricsResolver _instance = LyricsResolver._internal();
  factory LyricsResolver() => _instance;
  LyricsResolver._internal();

  final http.Client _client = http.Client();

  /// Get synchronized lyrics for a track
  /// Tries LRCLib → Kugou → Kizzy in order
  Future<SyncedLyrics?> getSyncedLyrics({
    required String title,
    required String artist,
    int durationMs = 0,
    String? album,
    String? isrc,
  }) async {
    // Try LRCLib first (most reliable for synced lyrics)
    final lrclibResult = await _tryLrcLib(
      title: title,
      artist: artist,
      durationMs: durationMs,
      album: album,
    );
    if (lrclibResult != null) {
      debugPrint('LyricsResolver: Found lyrics via LRCLib');
      return lrclibResult;
    }

    // Try Kugou (good for Chinese/Asian music)
    final kugouResult = await _tryKugou(
      title: title,
      artist: artist,
      durationMs: durationMs,
    );
    if (kugouResult != null) {
      debugPrint('LyricsResolver: Found lyrics via Kugou');
      return kugouResult;
    }

    // Try Kizzy (alternative source)
    final kizzyResult = await _tryKizzy(
      title: title,
      artist: artist,
      durationMs: durationMs,
    );
    if (kizzyResult != null) {
      debugPrint('LyricsResolver: Found lyrics via Kizzy');
      return kizzyResult;
    }

    debugPrint('LyricsResolver: No lyrics found for $title - $artist');
    return null;
  }

  /// Try LRCLib API
  Future<SyncedLyrics?> _tryLrcLib({
    required String title,
    required String artist,
    int durationMs = 0,
    String? album,
  }) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final url = 'https://lrclib.net/api/search?q=$query';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final results = jsonDecode(response.body) as List;
      if (results.isEmpty) return null;

      // Find best match
      for (final item in results) {
        final synced = item['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) {
          return SyncedLyrics(
            source: 'lrclib',
            lines: _parseLrc(synced),
            raw: synced,
          );
        }
      }
    } catch (e) {
      debugPrint('LRCLib error: $e');
    }
    return null;
  }

  /// Try Kugou API (Chinese lyrics source)
  Future<SyncedLyrics?> _tryKugou({
    required String title,
    required String artist,
    int durationMs = 0,
  }) async {
    try {
      // Kugou API endpoint (public)
      final url = 'https://lyrics.kugou.com/search?keyword=${Uri.encodeComponent('$title $artist')}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      // Parse Kugou response format
      final data = jsonDecode(response.body);
      final lyrics = data['data']?['lyrics'] as String?;
      if (lyrics != null && lyrics.isNotEmpty) {
        return SyncedLyrics(
          source: 'kugou',
          lines: _parseLrc(lyrics),
          raw: lyrics,
        );
      }
    } catch (e) {
      debugPrint('Kugou error: $e');
    }
    return null;
  }

  /// Try Kizzy API (alternative)
  Future<SyncedLyrics?> _tryKizzy({
    required String title,
    required String artist,
    int durationMs = 0,
  }) async {
    try {
      // Kizzy API (example endpoint)
      final url = 'https://api.kizzy.io/lyrics?title=${Uri.encodeComponent(title)}&artist=${Uri.encodeComponent(artist)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final lyrics = data['syncedLyrics'] as String?;
      if (lyrics != null && lyrics.isNotEmpty) {
        return SyncedLyrics(
          source: 'kizzy',
          lines: _parseLrc(lyrics),
          raw: lyrics,
        );
      }
    } catch (e) {
      debugPrint('Kizzy error: $e');
    }
    return null;
  }

  /// Parse LRC format to list of LyricLine
  List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})[.:](\d{2,3})\](.*)');

    for (final line in lrc.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centis = int.parse(match.group(3)!.padRight(3, '0').substring(0, 2));
        final text = match.group(4)!.trim();

        final timeMs = (minutes * 60 + seconds) * 1000 + centis * 10;
        lines.add(LyricLine(timeMs: timeMs, text: text));
      }
    }

    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return lines;
  }

  void dispose() {}
}

/// Synchronized lyrics result
class SyncedLyrics {
  final String source;
  final List<LyricLine> lines;
  final String raw;

  SyncedLyrics({
    required this.source,
    required this.lines,
    required this.raw,
  });

  /// Get current lyric line for given time
  LyricLine? getLineAt(int timeMs) {
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].timeMs <= timeMs) {
        return lines[i];
      }
    }
    return lines.isNotEmpty ? lines.first : null;
  }

  /// Get next lyric line after given time
  LyricLine? getNextLine(int timeMs) {
    for (final line in lines) {
      if (line.timeMs > timeMs) return line;
    }
    return null;
  }
}

/// Individual lyric line with timestamp
class LyricLine {
  final int timeMs;
  final String text;

  LyricLine({required this.timeMs, required this.text});

  @override
  String toString() => '[${_formatTime(timeMs)}] $text';

  String _formatTime(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final centis = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';
  }
}

/// Singleton instance
final lyricsResolver = LyricsResolver();