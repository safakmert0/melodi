import 'dart:convert';
import 'dart:io';
import '../music_source.dart';

class DeezerSource implements MusicSource {
  static const _searchUrl = 'https://api.deezer.com/search';
  static const _trackUrl = 'https://api.deezer.com/track';

  @override
  MusicSourceType get type => MusicSourceType.deezer;

  @override
  String get name => 'Deezer';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_searchUrl?q=${Uri.encodeComponent(query)}&limit=$limit');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/3.3.0');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return [];
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final tracks = data['data'] as List?;
      if (tracks == null) return [];
      final results = <OnlineTrack>[];
      for (final track in tracks) {
        if (results.length >= limit) break;
        final id = track['id']?.toString() ?? '';
        final title = track['title']?.toString() ?? '';
        final artist = track['artist']?['name']?.toString() ?? '';
        final album = track['album']?['title']?.toString();
        final duration = Duration(seconds: track['duration'] ?? 0);
        final preview = track['preview']?.toString();
        results.add(OnlineTrack(
          id: 'deezer_$id',
          title: title,
          artist: artist,
          album: album,
          duration: duration,
          thumbnailUrl: track['album']?['cover_medium']?.toString(),
          source: MusicSourceType.deezer,
          streamUrl: preview,
        ));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    // Deezer provides 30-second preview URLs directly
    if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
      return track.streamUrl;
    }
    // Try to get the full track URL (requires authentication)
    try {
      final trackId = track.id.replaceFirst('deezer_', '');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_trackUrl/$trackId');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/3.3.0');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['preview']?.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
