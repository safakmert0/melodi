import 'dart:convert';
import 'dart:io';
import '../music_source.dart';

class LastFmSource implements MusicSource {
  static const _apiKey = '5c14090639e15e1c09e7c1d4d0322a74';
  static const _baseUrl = 'https://ws.audioscrobbler.com/2.0/';

  @override
  MusicSourceType get type => MusicSourceType.lastfm;

  @override
  String get name => 'Last.fm';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_baseUrl?method=track.search&track=${Uri.encodeComponent(query)}&api_key=$_apiKey&format=json&limit=$limit');
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return [];
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final matches = data['results']?['trackmatches']?['track'] as List?;
      if (matches == null) return [];
      final results = <OnlineTrack>[];
      for (final track in matches) {
        if (results.length >= limit) break;
        final name = track['name']?.toString() ?? '';
        final artist = track['artist']?.toString() ?? '';
        // Last.fm search doesn't return duration, use 0
        results.add(OnlineTrack(
          id: 'lastfm_${track['mbid'] ?? name.hashCode}',
          title: name,
          artist: artist,
          source: MusicSourceType.lastfm,
        ));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    // Last.fm doesn't provide streaming URLs directly
    // This is primarily for metadata and discovery
    return null;
  }

  @override
  Future<void> dispose() async {}
}
