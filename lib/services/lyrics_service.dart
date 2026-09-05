import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/extension.dart';
import 'extension_service.dart';
import 'js_extension_service.dart';
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
  static final RegExp _timestamp =
      RegExp(r'^(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?$');
  static final RegExp _offset =
      RegExp(r'^\[offset:([+-]?\d+)\]\s*$', caseSensitive: false);

  static List<LrcLine> parse(String body) {
    if (body.trim().isEmpty) return [];
    final out = <LrcLine>[];
    var offsetMs = 0;
    for (final rawLine in body.split('\n')) {
      final match = _offset.firstMatch(rawLine.trim());
      if (match != null) {
        offsetMs = int.tryParse(match.group(1)!) ?? 0;
      }
    }
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
        out.add(LrcLine((ms + offsetMs).clamp(0, 1 << 31), text));
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
    final frac = match.group(3) ?? '0';
    final fracMs = frac.length == 1
        ? int.parse(frac) * 100
        : frac.length == 2
            ? int.parse(frac) * 10
            : int.parse(frac);
    return (minutes * 60000) + (seconds * 1000) + fracMs;
  }
}

class LyricsTiming {
  const LyricsTiming._();

  static double _durationScale(int playbackDurationMs, int lyricsDurationMs) {
    if (playbackDurationMs <= 0 || lyricsDurationMs <= 0) return 1;
    final ratio = lyricsDurationMs / playbackDurationMs;
    return ratio >= 0.85 && ratio <= 1.15 ? ratio : 1;
  }

  static int lyricPositionMs({
    required int playbackPositionMs,
    int manualOffsetMs = 0,
    int playbackDurationMs = 0,
    int lyricsDurationMs = 0,
  }) {
    final adjusted = (playbackPositionMs - manualOffsetMs).clamp(0, 1 << 31);
    return (adjusted * _durationScale(playbackDurationMs, lyricsDurationMs))
        .round();
  }

  static int playbackPositionMs({
    required int lyricPositionMs,
    int manualOffsetMs = 0,
    int playbackDurationMs = 0,
    int lyricsDurationMs = 0,
  }) {
    final scale = _durationScale(playbackDurationMs, lyricsDurationMs);
    return ((lyricPositionMs / scale).round() + manualOffsetMs)
        .clamp(0, 1 << 31);
  }

  static int findLineIndex(List<LrcLine> lines, int positionMs) {
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (lines[middle].timestampMs <= positionMs) {
        found = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return found;
  }

  static int findLineIndexAtPlayback({
    required List<LrcLine> lines,
    required int playbackPositionMs,
    int manualOffsetMs = 0,
    int playbackDurationMs = 0,
    int lyricsDurationMs = 0,
  }) {
    return findLineIndex(
      lines,
      lyricPositionMs(
        playbackPositionMs: playbackPositionMs,
        manualOffsetMs: manualOffsetMs,
        playbackDurationMs: playbackDurationMs,
        lyricsDurationMs: lyricsDurationMs,
      ),
    );
  }
}

class LyricsResult {
  final String? plainText;
  final String? syncedLrc;
  final bool instrumental;
  final String? source;
  final int? durationMs;

  const LyricsResult({
    this.plainText,
    this.syncedLrc,
    this.instrumental = false,
    this.source,
    this.durationMs,
  });
}

class LyricsService {
  static const _baseUrl = 'https://lrclib.net';
  static const _userAgent = 'Melodi/1.0';

  static final DatabaseService _db = DatabaseService.instance;

  static final List<int> _durationLadder = [
    0,
    -1,
    1,
    -2,
    2,
    -3,
    3,
    -4,
    4,
    -5,
    5
  ];

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

  static Future<void> _writeSidecar(
      String audioPath, LyricsResult result) async {
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
    bool preferSynced = false,
  }) async {
    LyricsResult? plainFallback;
    if (filePath != null) {
      final sidecar = await _readSidecar(filePath);
      if (sidecar != null) {
        if (!preferSynced || _hasSyncedLyrics(sidecar)) return sidecar;
        plainFallback = sidecar;
      }
    }

    final songId = '${artist}_${track}_${album ?? ''}';

    final cached = await _getCachedLyrics(songId);
    if (cached != null) {
      if (!preferSynced || _hasSyncedLyrics(cached)) return cached;
      plainFallback ??= cached;
    }

    final result = await _fetchFromApi(
        artist: artist, track: track, album: album, durationMs: durationMs);

    if (result != null) {
      await _cacheLyrics(songId, result);
      if (filePath != null) {
        await _writeSidecar(filePath, result);
      }
    }

    return result ?? plainFallback;
  }

  static bool _hasSyncedLyrics(LyricsResult result) =>
      result.syncedLrc != null && result.syncedLrc!.trim().isNotEmpty;

  static Future<LyricsResult?> _fetchFromApi({
    required String artist,
    required String track,
    String? album,
    int? durationMs,
  }) async {
    if (durationMs != null) {
      final baseSec = (durationMs / 1000).round();
      final valid = _durationLadder
          .map((delta) => baseSec + delta)
          .where((seconds) => seconds > 0)
          .toList();
      for (var offset = 0; offset < valid.length; offset += 3) {
        final end = (offset + 3).clamp(0, valid.length);
        final result = await _firstLyrics([
          for (final sec in valid.sublist(offset, end))
            () => _tryGet(
                artist: artist, track: track, album: album, durationSec: sec),
        ]);
        if (result != null) return result;
      }
    }

    final searched = await _trySearch(artist, track);
    if (searched != null) return searched;
    return _tryCommunityProviders(
      artist: artist,
      track: track,
      durationMs: durationMs,
    );
  }

  static Future<LyricsResult?> _tryCommunityProviders({
    required String artist,
    required String track,
    int? durationMs,
  }) async {
    final durationSec = durationMs == null ? null : (durationMs / 1000).round();
    final batches = <List<Future<LyricsResult?> Function()>>[
      [
        () => _tryExtensionLyrics(artist, track, durationMs),
        () => _tryPaxSearchProvider('spotify', artist, track),
        () => _tryPaxDirect(
              'musixmatch/lyrics',
              {
                't': track,
                'a': artist,
                'type': 'word',
                'format': 'lrc',
                if (durationSec != null) 'd': '$durationSec',
              },
              'musixmatch',
            ),
      ],
      [
        () => _tryCatalogLyrics('apple-music', artist, track),
        () => _tryCatalogLyrics('deezer', artist, track),
        () => _tryPaxSearchProvider('youtube', artist, track),
      ],
      [
        () => _tryPaxSearchProvider('netease', artist, track),
        () => _tryQQMusic(artist, track),
        () => _tryKugou(artist, track, durationMs),
      ],
      [
        () => _tryLyricsPlus(artist, track, durationSec),
        () => _tryGenius(artist, track),
      ],
    ];
    for (final batch in batches) {
      final result = await _firstLyrics(batch);
      if (result != null) return result;
    }
    return null;
  }

  static Future<LyricsResult?> _firstLyrics(
      List<Future<LyricsResult?> Function()> attempts) {
    final completer = Completer<LyricsResult?>();
    var remaining = attempts.length;
    for (final attempt in attempts) {
      Future.sync(attempt)
          .timeout(const Duration(seconds: 12))
          .then((value) {
            if (value != null && !completer.isCompleted)
              completer.complete(value);
          })
          .catchError((_) => null)
          .whenComplete(() {
            remaining--;
            if (remaining == 0 && !completer.isCompleted)
              completer.complete(null);
          });
    }
    return completer.future;
  }

  static Future<LyricsResult?> _tryQQMusic(String artist, String track) async {
    final search = await _getJson(
      Uri.parse('https://c.y.qq.com/soso/fcgi-bin/client_search_cp')
          .replace(queryParameters: {
        'format': 'json',
        'platform': 'yqq.json',
        'new_json': '1',
        'w': '$track $artist',
        'p': '1',
        'n': '10',
      }),
    );
    if (search is! Map) return null;
    final data = search['data'];
    final song = data is Map ? data['song'] : null;
    final list = song is Map ? song['list'] as List? : null;
    if (list == null || list.isEmpty || list.first is! Map) return null;
    final first = Map<String, dynamic>.from(list.first as Map);
    final mid = first['mid'] ?? first['songmid'];
    final id = first['id'] ?? first['songid'];
    if (mid == null) return null;
    final lyrics = await _getJson(
      Uri.parse('https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg')
          .replace(queryParameters: {
        'format': 'json',
        'platform': 'yqq.json',
        'songmid': '$mid',
        if (id != null) 'songid': '$id',
      }),
    );
    if (lyrics is! Map || lyrics['lyric'] == null) return null;
    try {
      final text = utf8.decode(base64Decode(lyrics['lyric'].toString()));
      return _lyricsFromFlexiblePayload(text, 'qqmusic');
    } catch (_) {
      return _lyricsFromFlexiblePayload(lyrics['lyric'], 'qqmusic');
    }
  }

  static Future<LyricsResult?> _tryKugou(
      String artist, String track, int? durationMs) async {
    final search = await _getJson(
      Uri.parse('https://lyrics.kugou.com/search').replace(queryParameters: {
        'ver': '1',
        'man': 'yes',
        'client': 'pc',
        'keyword': '$artist - $track',
        'duration': '${durationMs ?? 0}',
      }),
    );
    if (search is! Map) return null;
    final candidates = search['candidates'] as List? ?? const [];
    if (candidates.isEmpty || candidates.first is! Map) return null;
    final first = Map<String, dynamic>.from(candidates.first as Map);
    final id = first['id'];
    final accessKey = first['accesskey'] ?? first['accessKey'];
    if (id == null || accessKey == null) return null;
    final payload = await _getJson(
      Uri.parse('https://lyrics.kugou.com/download').replace(queryParameters: {
        'ver': '1',
        'client': 'pc',
        'id': '$id',
        'accesskey': '$accessKey',
        'fmt': 'lrc',
        'charset': 'utf8',
      }),
    );
    if (payload is! Map || payload['content'] == null) return null;
    try {
      final text = utf8.decode(base64Decode(payload['content'].toString()));
      return _lyricsFromFlexiblePayload(text, 'kugou');
    } catch (_) {
      return null;
    }
  }

  static Future<LyricsResult?> _tryCatalogLyrics(
      String provider, String artist, String track) async {
    dynamic search;
    if (provider == 'deezer') {
      search = await _getJson(Uri.parse('https://api.deezer.com/search')
          .replace(queryParameters: {'q': 'artist:"$artist" track:"$track"'}));
    } else {
      search = await _getJson(Uri.parse('https://itunes.apple.com/search')
          .replace(queryParameters: {
        'term': '$artist $track',
        'entity': 'song',
        'limit': '5',
      }));
    }
    final items = search is Map
        ? (search['data'] as List? ?? search['results'] as List? ?? const [])
        : const [];
    if (items.isEmpty || items.first is! Map) return null;
    final first = Map<String, dynamic>.from(items.first as Map);
    final id = first['id'] ?? first['trackId'];
    if (id == null) return null;
    return _tryPaxDirect('$provider/lyrics', {'id': '$id'}, provider);
  }

  static Future<LyricsResult?> _tryGenius(String artist, String track) async {
    final search = await _getJson(
        Uri.parse('https://genius.com/api/search/multi').replace(
            queryParameters: {'q': '$track $artist', 'per_page': '5'}));
    if (search is! Map) return null;
    final response = search['response'];
    if (response is! Map) return null;
    final sections = response['sections'] as List? ?? const [];
    String? pageUrl;
    for (final section in sections.whereType<Map>()) {
      for (final hit
          in (section['hits'] as List? ?? const []).whereType<Map>()) {
        final result = hit['result'];
        if (result is Map && result['url'] != null) {
          pageUrl = result['url'].toString();
          break;
        }
      }
      if (pageUrl != null) break;
    }
    if (pageUrl == null) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(pageUrl));
      request.headers.set('User-Agent', _userAgent);
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final document =
          html_parser.parse(await response.transform(utf8.decoder).join());
      final containers =
          document.querySelectorAll('[data-lyrics-container="true"]');
      final text = containers
          .map((node) => node.text.trim())
          .where((value) => value.isNotEmpty)
          .join('\n');
      return text.isEmpty
          ? null
          : LyricsResult(plainText: text, source: 'genius');
    } finally {
      client.close(force: true);
    }
  }

  static Future<LyricsResult?> _tryExtensionLyrics(
      String artist, String track, int? durationMs) async {
    await ExtensionService.instance.ensureLoaded();
    for (final installed in ExtensionService.instance.installed) {
      final manifest = installed.manifest;
      if (!installed.enabled || !manifest.capabilities.contains('lyrics'))
        continue;
      final bundle = manifest.homepage;
      if (bundle == null || bundle.isEmpty) continue;
      final value = await JsExtensionService.instance.fetchLyrics(
        RegistryEntry(
          id: manifest.id,
          name: manifest.name,
          url: bundle,
          version: manifest.version,
          kind: manifest.kind,
          permissions: manifest.permissions,
        ),
        title: track,
        artist: artist,
        durationMs: durationMs,
      );
      final parsed = _lyricsFromFlexiblePayload(value, manifest.name);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static Future<LyricsResult?> _tryPaxSearchProvider(
      String provider, String artist, String track) async {
    final search = await _getJson(
      Uri.parse('https://lyrics.paxsenix.org/$provider/search')
          .replace(queryParameters: {'q': '$track $artist'}),
    );
    final items = search is List
        ? search
        : search is Map
            ? (search['results'] as List? ??
                search['songs'] as List? ??
                const [])
            : const [];
    if (items.isEmpty || items.first is! Map) return null;
    final first = Map<String, dynamic>.from(items.first as Map);
    final id = first['trackId'] ?? first['videoId'] ?? first['id'];
    if (id == null || id.toString().isEmpty) return null;
    return _tryPaxDirect(
      '$provider/lyrics',
      {'id': id.toString()},
      provider,
    );
  }

  static Future<LyricsResult?> _tryPaxDirect(
    String path,
    Map<String, String> params,
    String provider,
  ) async {
    final payload = await _getJson(
      Uri.parse('https://lyrics.paxsenix.org/$path')
          .replace(queryParameters: params),
    );
    return _lyricsFromFlexiblePayload(payload, provider);
  }

  static Future<LyricsResult?> _tryLyricsPlus(
      String artist, String track, int? durationSec) async {
    for (final base in const [
      'https://lyricsplus.prjktla.workers.dev',
      'https://lyricsplus.binimum.org',
    ]) {
      final payload = await _getJson(
        Uri.parse('$base/v2/lyrics/get').replace(queryParameters: {
          'title': track,
          'artist': artist,
          if (durationSec != null) 'duration': '$durationSec',
        }),
      );
      final parsed = _lyricsFromFlexiblePayload(payload, 'lyricsplus');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept', 'application/json');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      if (body.trim().isEmpty) return null;
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    } finally {
      client.close(force: true);
    }
  }

  static LyricsResult? _lyricsFromFlexiblePayload(
      dynamic payload, String provider) {
    String? text;
    if (payload is String) {
      text = payload;
    } else if (payload is Map) {
      for (final key in const [
        'syncedLyrics',
        'lyrics',
        'lyric',
        'lyrics_text',
        'plain_lyrics'
      ]) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) {
          text = value;
          break;
        }
      }
      final lines = payload['content'] ?? payload['lyrics'];
      if (text == null && lines is List) {
        final out = StringBuffer();
        for (final raw in lines.whereType<Map>()) {
          final line = Map<String, dynamic>.from(raw);
          final words = line['text'] ?? line['words'] ?? line['content'];
          if (words == null) continue;
          final time = line['time'] ?? line['startTime'] ?? line['start'];
          if (time is num) {
            final ms = time > 100000 ? time.round() : (time * 1000).round();
            final min = (ms ~/ 60000).toString().padLeft(2, '0');
            final sec =
                ((ms % 60000) / 1000).toStringAsFixed(2).padLeft(5, '0');
            out.writeln('[$min:$sec]$words');
          } else {
            out.writeln(words);
          }
        }
        text = out.toString();
      }
    }
    if (text == null || text.trim().isEmpty) return null;
    final value = text.trim();
    final synced =
        RegExp(r'^\s*\[\d{1,3}:\d{2}', multiLine: true).hasMatch(value);
    return LyricsResult(
      plainText:
          synced ? value.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim() : value,
      syncedLrc: synced ? value : null,
      source: provider,
    );
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
      final uri =
          Uri.parse('$_baseUrl/api/get').replace(queryParameters: params);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
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
      final uri = Uri.parse('$_baseUrl/api/search')
          .replace(queryParameters: {'q': query});
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
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
    if (!instrumental &&
        (syncedLrc == null || syncedLrc.isEmpty) &&
        (plainText == null || plainText.isEmpty)) {
      return null;
    }
    return LyricsResult(
      plainText: plainText,
      syncedLrc: syncedLrc,
      instrumental: instrumental,
      source: 'lrclib',
      durationMs: data['duration'] is num
          ? ((data['duration'] as num) * 1000).round()
          : null,
    );
  }

  static Future<LyricsResult?> _getCachedLyrics(String songId) async {
    try {
      final db = await _db.database;
      final maps = await db
          .query('lyrics_cache', where: 'songId = ?', whereArgs: [songId]);
      if (maps.isEmpty) return null;
      final row = maps.first;
      return LyricsResult(
        plainText: row['plainText'] as String?,
        syncedLrc: row['syncedLrc'] as String?,
        instrumental: (row['instrumental'] as int?) == 1,
        source: row['source'] as String?,
        durationMs: row['durationMs'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cacheLyrics(String songId, LyricsResult result) async {
    try {
      final db = await _db.database;
      await db.insert(
          'lyrics_cache',
          {
            'songId': songId,
            'plainText': result.plainText,
            'syncedLrc': result.syncedLrc,
            'instrumental': result.instrumental ? 1 : 0,
            'source': result.source,
            'durationMs': result.durationMs,
            'fetchedAt': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<List<LrcLine>> parseLrc(String lrc) async {
    return LrcParser.parse(lrc);
  }
}
