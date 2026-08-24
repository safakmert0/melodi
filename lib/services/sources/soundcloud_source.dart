import 'dart:async';
import 'dart:convert';
import '../music_source.dart';

class SoundCloudSource implements MusicSource {
  static const String _baseUrl = 'https://api-v2.soundcloud.com';
  static const String _clientId = 'YOUR_SOUNDCLOUD_CLIENT_ID';

  @override
  MusicSourceType get type => MusicSourceType.soundcloud;

  @override
  String get name => 'SoundCloud';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_baseUrl/search/tracks')
          .replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
        'client_id': _clientId,
      });

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/4.0');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return [];
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final collection = data['collection'] as List?;
      if (collection == null) return [];

      return collection
          .whereType<Map<String, dynamic>>()
          .map(_parseTrack)
          .whereType<OnlineTrack>()
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('SoundCloud search error: $e');
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
      return track.streamUrl;
    }

    try {
      final trackId = track.id.replaceFirst('soundcloud_', '');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_baseUrl/tracks/$trackId/streams')
          .replace(queryParameters: {'client_id': _clientId});
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/4.0');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['http_mp3_128_url'] as String?;
    } catch (e) {
      debugPrint('SoundCloud stream error: $e');
      return null;
    }
  }

  OnlineTrack? _parseTrack(Map<String, dynamic> track) {
    try {
      final id = track['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final title = track['title'] as String? ?? '';
      final user = track['user'] as Map<String, dynamic>?;
      final artist = user?['username'] as String? ?? '';
      final durationMs = track['duration'] as int? ?? 0;
      final artwork = track['artwork_url'] as String?;
      final streamUrl = track['media']?['transcodings'] != null
          ? _extractStreamUrl(track['media']['transcodings'])
          : track['stream_url'] as String?;

      return OnlineTrack(
        id: 'soundcloud_$id',
        title: title,
        artist: artist,
        duration: Duration(milliseconds: durationMs),
        thumbnailUrl: artwork?.replaceAll('large', 't500x500'),
        source: MusicSourceType.soundcloud,
        streamUrl: streamUrl,
      );
    } catch (e) {
      debugPrint('SoundCloud parse error: $e');
      return null;
    }
  }

  String? _extractStreamUrl(List<dynamic> transcodings) {
    for (final t in transcodings) {
      if (t is Map && t['format'] is Map) {
        final format = t['format'] as Map<String, dynamic>;
        if (format['protocol'] == 'progressive' &&
            format['mime_type'] == 'audio/mpeg') {
          return t['url'] as String?;
        }
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {}
}