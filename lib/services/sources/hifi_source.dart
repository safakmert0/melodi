import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/extension.dart';
import '../database_service.dart';
import '../cloudflare_session_service.dart';
import '../extension_service.dart';
import '../music_source.dart';

/// Sunucu tarafındaki Melodi backend'i üzerinden çalışan lossless kaynak.
///
/// Arama Spotify kataloğunda yapılır; parça çalınmadan önce sunucu tarafından
/// FLAC olarak kütüphaneye indirilir ve Navidrome üzerinden akıtılır. Böylece
/// "ara → çal" akışı doğrudan kayıpsız kalitede çalışır.
class HiFiSource implements MusicSource {
  static const String defaultBaseUrl =
      'https://butterfly-crawford-parenting-spotlight.trycloudflare.com';
  static const String _baseUrlKey = 'hifi_backend_url';
  static const Duration _searchTimeout = Duration(seconds: 30);
  static const Duration _downloadTimeout = Duration(minutes: 5);

  @override
  MusicSourceType get type => MusicSourceType.hifi;

  @override
  String get name => 'Hi-Fi';

  Future<String> baseUrl() async {
    // Etkin lossless eklentisi varsa adresi eklenti belirler.
    try {
      final endpoint =
          await ExtensionService.instance.resolveEndpoint(ExtensionKind.hifi);
      if (endpoint != null && endpoint.isNotEmpty) return endpoint;
    } catch (_) {}
    try {
      final saved = await DatabaseService.instance.getSetting(_baseUrlKey);
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}
    return defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    await DatabaseService.instance.setSetting(_baseUrlKey, normalized);
    _reachableCache.clear();
  }

  String? _reachableBase;
  DateTime? _reachableCheckedAt;
  static const Duration _reachableTtl = Duration(minutes: 2);
  final Map<String, bool> _reachableCache = {};

  /// Ölü baza (çözülmeyen tünel vb.) 30 sn/5 dk gömülmeden hızlı elen.
  Future<bool> _isBaseReachable(String base) async {
    final now = DateTime.now();
    if (_reachableBase == base &&
        _reachableCheckedAt != null &&
        now.difference(_reachableCheckedAt!) < _reachableTtl) {
      return _reachableCache[base] ?? false;
    }
    var reachable = false;
    try {
      final response = await http
          .get(Uri.parse(base), headers: {'User-Agent': 'Melodi/1.0'})
          .timeout(const Duration(seconds: 5));
      reachable = response.statusCode < 500;
    } catch (_) {
      reachable = false;
    }
    _reachableBase = base;
    _reachableCheckedAt = now;
    _reachableCache[base] = reachable;
    return reachable;
  }

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final base = await baseUrl();
      if (!await _isBaseReachable(base)) return const [];
      final response = await CloudflareSessionService.instance
          .post(
            Uri.parse('$base/api/hifi/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': trimmed, 'limit': limit}),
          )
          .timeout(_searchTimeout);

      if (response.statusCode != 200) {
        debugPrint('HiFi search error: ${response.statusCode}');
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = (data['tracks'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .where((t) => (t['spotify_url'] ?? '').toString().isNotEmpty)
          .map((t) => OnlineTrack(
                id: t['spotify_url'].toString(),
                title: t['title']?.toString() ?? 'Bilinmeyen parça',
                artist: t['author']?.toString() ?? 'Bilinmeyen sanatçı',
                album: t['album']?.toString(),
                duration: Duration(
                  seconds: (t['duration'] as num?)?.toInt() ?? 0,
                ),
                thumbnailUrl: t['thumbnail']?.toString(),
                source: MusicSourceType.hifi,
              ))
          .toList();
      return tracks;
    } catch (e) {
      debugPrint('HiFi search error: $e');
      return const [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    final base = await baseUrl();
    if (!await _isBaseReachable(base)) return null;

    // 1) Parça zaten kütüphanedeyse indirmeden direkt akıt.
    final existing = await _findInLibrary(base, track);
    if (existing != null) return existing;

    // 2) Kütüphanede yoksa sunucuda FLAC indirilir (30-120 sn sürebilir).
    try {
      final response = await CloudflareSessionService.instance
          .post(
            Uri.parse('$base/api/hifi/download'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'spotify_url': track.id}),
          )
          .timeout(_downloadTimeout);

      if (response.statusCode != 200) {
        debugPrint('HiFi download error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final song = data['song'] as Map<String, dynamic>?;
      final streamPath = song?['stream_url']?.toString();
      if (streamPath == null || streamPath.isEmpty) return null;
      return '$base$streamPath';
    } catch (e) {
      debugPrint('HiFi download error: $e');
      return null;
    }
  }

  Future<String?> _findInLibrary(String base, OnlineTrack track) async {
    try {
      final needle = track.title.trim().toLowerCase();
      if (needle.isEmpty) return null;
      final response = await CloudflareSessionService.instance
          .get(
            Uri.parse('$base/api/library/search')
                .replace(queryParameters: {'query': track.title.trim()}),
          )
          .timeout(_searchTimeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final songs = (data['songs'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw));

      for (final song in songs) {
        final songTitle = song['title']?.toString().toLowerCase() ?? '';
        final sameTitle = songTitle == needle ||
            songTitle.startsWith(needle) ||
            needle.startsWith(songTitle);
        final artist = track.artist.toLowerCase();
        final songArtist = song['artist']?.toString().toLowerCase() ?? '';
        final artistMatches =
            artist.isEmpty || songArtist.contains(artist.split(',').first);
        if (sameTitle && artistMatches) {
          final streamPath = song['stream_url']?.toString();
          if (streamPath != null && streamPath.isNotEmpty) {
            return '$base$streamPath';
          }
        }
      }
    } catch (e) {
      debugPrint('HiFi library lookup error: $e');
    }
    return null;
  }

  @override
  Future<void> dispose() async {}
}
