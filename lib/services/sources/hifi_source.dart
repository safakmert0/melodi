import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database_service.dart';
import '../music_source.dart';

/// Kayıpsız müzik kaynağı: Melodi backend üzerinden Spotify kataloğunda
/// arama, sunucuda FLAC indirme ve kütüphaneden akış.
///
/// Akış: ara → sunucu FLAC indirir → Navidrome kütüphanesine ekler →
/// `/api/library/stream/{id}` döner (30-120 sn sürebilir).
class HiFiSource implements MusicSource {
  // Sunucu adresi IPA içinde düz metin durmasın diye XOR+base64 ile saklanır
  // (statik `strings` incelemesine karşı; ağ trafiğinde zaten TLS var).
  // Not: kararlı tersine mühendisliğe karşı tam koruma sağlamaz.
  static const String _encBaseUrl =
      'JREYHxdTZ0YrDE9dVFsYE3xWQV5QW2VYdV0OAQccWEg9SwUA';
  static const List<int> _encKey = [
    77, 101, 108, 111, 100, 105, 72, 105, 70, 105, 35, 50, 48, 50, 54, 33
  ];

  static String get defaultBaseUrl {
    try {
      final raw = base64Decode(_encBaseUrl);
      final plain =
          List<int>.generate(raw.length, (i) => raw[i] ^ _encKey[i % 16]);
      final url = utf8.decode(plain).trim();
      if (url.startsWith('https://')) return url;
    } catch (_) {}
    return '';
  }

  static const String _baseUrlKey = 'hifi_backend_url';
  static const Duration _searchTimeout = Duration(seconds: 30);
  static const Duration _downloadTimeout = Duration(minutes: 5);

  @override
  MusicSourceType get type => MusicSourceType.hifi;

  @override
  String get name => 'Hi-Fi';

  Future<String> baseUrl() async {
    try {
      final saved = await DatabaseService.instance.getSetting(_baseUrlKey);
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}
    return defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    await DatabaseService.instance.setSetting(_baseUrlKey, normalized);
  }

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final base = await baseUrl();
      final response = await http
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

    // 1) Parça zaten kütüphanedeyse indirmeden direkt akıt.
    final existing = await _findInLibrary(base, track);
    if (existing != null) return existing;

    // 2) Kütüphanede yoksa sunucuda FLAC indirilir (30-120 sn sürebilir).
    try {
      final response = await http
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
      if (streamPath != null && streamPath.isNotEmpty) {
        return '$base$streamPath';
      }
      // Sunucu indirdi ama tarama bitmeden `song` boş dönebilir. Bu durumda
      // indirme "başarısız" sayılmamalı: kütüphanede kısa süre bekle.
      if (data['status'] == 'done') {
        for (var i = 0; i < 8; i++) {
          await Future.delayed(const Duration(seconds: 5));
          final found = await _findInLibrary(base, track);
          if (found != null) return found;
        }
        debugPrint('HiFi downloaded but not yet in library: ${track.title}');
      }
      return null;
    } catch (e) {
      debugPrint('HiFi download error: $e');
      return null;
    }
  }

  Future<String?> _findInLibrary(String base, OnlineTrack track) async {
    try {
      final needle = track.title.trim().toLowerCase();
      if (needle.isEmpty) return null;
      final response = await http
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
