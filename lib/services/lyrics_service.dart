import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

class LrcLine {
  final int timestampMs;
  final String text;
  const LrcLine(this.timestampMs, this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LrcLine &&
          runtimeType == other.runtimeType &&
          timestampMs == other.timestampMs &&
          text == other.text;

  @override
  int get hashCode => Object.hash(timestampMs, text);
}

class LrcParser {
  static final RegExp _metaTag = RegExp(
    r'^\[(ti|ar|al|length|by|offset|au|re|ve):.*\]\s*$',
    caseSensitive: false,
  );
  static final RegExp _timestamp = RegExp(r'^(\d{1,2}):(\d{2})\.(\d{2,3})$');

  static List<LrcLine> parse(String body) {
    if (body.trim().isEmpty) return [];
    final out = <LrcLine>[];
    for (final rawLine in body.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      if (_metaTag.hasMatch(line)) continue;

      final timestamps = <int>[];
      var idx = 0;
      while (idx < line.length && line[idx] == '[') {
        final close = line.indexOf(']', idx);
        if (close == -1) break;
        final token = line.substring(idx + 1, close);
        final ms = _parseTimestampMs(token);
        if (ms == null) break;
        timestamps.add(ms);
        idx = close + 1;
      }
      if (timestamps.isEmpty) continue;
      final text = line.substring(idx).trimRight();
      if (text.isEmpty) continue;
      for (final ms in timestamps) {
        out.add(LrcLine(ms, text));
      }
    }
    out.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return out;
  }

  static int? _parseTimestampMs(String token) {
    final match = _timestamp.firstMatch(token);
    if (match == null) return null;
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final frac = match.group(3)!;
    final fracMs = frac.length == 2
        ? int.parse(frac) * 10
        : int.parse(frac);
    return (minutes * 60000) + (seconds * 1000) + fracMs;
  }
}

class LyricsResult {
  final String? plainText;
  final String? syncedLrc;
  final bool instrumental;
  final String? source;

  const LyricsResult({
    this.plainText,
    this.syncedLrc,
    this.instrumental = false,
    this.source,
  });
}

class LyricsService {
  static const _baseUrl = 'https://lrclib.net';
  static const _userAgent = 'Melodi/1.0';

  static final DatabaseService _db = DatabaseService.instance;

  static final List<int> _durationLadder = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5];

  static String _sidecarPath(String audioPath) {
    final dot = audioPath.lastIndexOf('.');
    final base = dot >= 0 ? audioPath.substring(0, dot) : audioPath;
    return '$base.lrc';
  }

  static Future<LyricsResult?> _readSidecar(String audioPath) async {
    try {
      final file = File(_sidecarPath(audioPath));
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      if (RegExp(r'\[\d+:\d+\.\d+\]').hasMatch(content)) {
        return LyricsResult(syncedLrc: content, source: 'sidecar');
      }
      return LyricsResult(plainText: content, source: 'sidecar');
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeSidecar(String audioPath, LyricsResult result) async {
    try {
      final content = result.syncedLrc ?? result.plainText;
      if (content == null || content.isEmpty) return;
      final file = File(_sidecarPath(audioPath));
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Failed to write sidecar: $e');
    }
  }

  static Future<LyricsResult?> fetchLyrics({
    required String artist,
    required String track,
    String? album,
    int? durationMs,
    String? filePath,
  }) async {
    if (filePath != null) {
      final sidecar = await _readSidecar(filePath);
      if (sidecar != null) return sidecar;
    }

    final songId = '${artist}_${track}_${album ?? ''}';

    final cached = await _getCachedLyrics(songId);
    if (cached != null) return cached;

    final result = await _fetchFromApi(artist: artist, track: track, album: album, durationMs: durationMs);

    if (result != null) {
      await _cacheLyrics(songId, result);
      if (filePath != null) {
        await _writeSidecar(filePath, result);
      }
    }

    return result;
  }

  static Future<LyricsResult?> _fetchFromApi({
    required String artist,
    required String track,
    String? album,
    int? durationMs,
  }) async {
    if (durationMs != null) {
      final baseSec = (durationMs / 1000).round();
      for (final delta in _durationLadder) {
        final sec = baseSec + delta;
        if (sec <= 0) continue;
        final result = await _tryGet(artist: artist, track: track, album: album, durationSec: sec);
        if (result != null) return result;
      }
    }

    return _trySearch(artist, track);
  }

  static Future<LyricsResult?> _tryGet({
    required String artist,
    required String track,
    String? album,
    required int durationSec,
  }) async {
    try {
      final params = {
        'track_name': track,
        'artist_name': artist,
        'duration': durationSec.toString(),
      };
      if (album != null && album.isNotEmpty) {
        params['album_name'] = album;
      }
      final uri = Uri.parse('$_baseUrl/api/get').replace(queryParameters: params);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent', _userAgent);
        request.headers.set('Accept', 'application/json');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          return _parseResponse(data);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Lyrics get error: $e');
    }
    return null;
  }

  static Future<LyricsResult?> _trySearch(String artist, String track) async {
    try {
      final query = '$artist $track';
      final uri = Uri.parse('$_baseUrl/api/search').replace(queryParameters: {'q': query});
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent', _userAgent);
        request.headers.set('Accept', 'application/json');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final list = jsonDecode(body) as List;
          if (list.isEmpty) return null;
          final first = list.first as Map<String, dynamic>;
          return _parseResponse(first);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Lyrics search error: $e');
    }
    return null;
  }

  static LyricsResult? _parseResponse(Map<String, dynamic> data) {
    final instrumental = data['instrumental'] == true;
    final syncedLrc = data['syncedLyrics'] as String?;
    final plainText = data['plainLyrics'] as String?;
    if (!instrumental && (syncedLrc == null || syncedLrc.isEmpty) && (plainText == null || plainText.isEmpty)) {
      return null;
    }
    return LyricsResult(
      plainText: plainText,
      syncedLrc: syncedLrc,
      instrumental: instrumental,
      source: 'lrclib',
    );
  }

  static Future<LyricsResult?> _getCachedLyrics(String songId) async {
    try {
      final db = await _db.database;
      final maps = await db.query('lyrics_cache', where: 'songId = ?', whereArgs: [songId]);
      if (maps.isEmpty) return null;
      final row = maps.first;
      return LyricsResult(
        plainText: row['plainText'] as String?,
        syncedLrc: row['syncedLrc'] as String?,
        instrumental: (row['instrumental'] as int?) == 1,
        source: row['source'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cacheLyrics(String songId, LyricsResult result) async {
    try {
      final db = await _db.database;
      await db.insert('lyrics_cache', {
        'songId': songId,
        'plainText': result.plainText,
        'syncedLrc': result.syncedLrc,
        'instrumental': result.instrumental ? 1 : 0,
        'source': result.source,
        'fetchedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<List<LrcLine>> parseLrc(String lrc) async {
    return LrcParser.parse(lrc);
  }
}
