import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database_service.dart';
import '../music_source.dart';
import 'hifi_source.dart';

/// SoundCloud kaynagi (Melodi backend: scsearch + genel cozucu).
/// Hesap istemez; akis backend uzerinden cozulur.
class SoundCloudSource implements MusicSource {
  @override
  MusicSourceType get type => MusicSourceType.soundcloud;

  @override
  String get name => 'SoundCloud';

  static const Duration _timeout = Duration(seconds: 30);

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final base = await HiFiSource().baseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/soundcloud/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': trimmed, 'limit': limit}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('SoundCloud search error: ${response.statusCode}');
        return const [];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ((data['tracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((raw) {
            final t = Map<String, dynamic>.from(raw as Map);
            final url = (t['url'] ?? '').toString();
            if (url.isEmpty) return null;
            return OnlineTrack(
              id: url,
              title: (t['title'] ?? 'Bilinmeyen parça').toString(),
              artist: (t['author'] ?? 'Bilinmeyen sanatçı').toString(),
              album: null,
              duration: Duration(
                seconds: (t['duration'] as num?)?.toInt() ?? 0,
              ),
              thumbnailUrl: t['thumbnail']?.toString(),
              source: MusicSourceType.soundcloud,
            );
          })
          .whereType<OnlineTrack>()
          .toList();
    } catch (e) {
      debugPrint('SoundCloud search error: $e');
      return const [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    final pageUrl = track.id.trim();
    if (pageUrl.isEmpty) return null;
    try {
      final base = await HiFiSource().baseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/resolve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': pageUrl}),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = (data['url'] ?? '').toString();
      return url.isEmpty ? null : url;
    } catch (e) {
      debugPrint('SoundCloud resolve error: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
