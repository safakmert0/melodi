import 'dart:convert';
import 'dart:io';
import '../music_source.dart';

class JioSaavnSource implements MusicSource {
  static const _searchUrl =
      'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0.407434645520672&cc=in&includeMetaTags=1&query=';
  static const _songUrl =
      'https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0.3648156743570088&api_version=4&_format=json&pids=';

  @override
  MusicSourceType get type => MusicSourceType.jiosaavn;

  @override
  String get name => 'JioSaavn';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_searchUrl${Uri.encodeComponent(query)}');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent',
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return [];
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final songs = data['songs']?['data'] as List?;
      if (songs == null) return [];
      final results = <OnlineTrack>[];
      for (final song in songs) {
        if (results.length >= limit) break;
        final id = song['id']?.toString() ?? '';
        final title = song['title']?.toString() ?? '';
        final artist = song['description']?.toString() ?? '';
        final duration = Duration(
            seconds: int.tryParse(song['duration']?.toString() ?? '0') ?? 0);
        final image = song['image']?['quality'] != null ? song['image'] : null;
        String? thumbUrl;
        if (image != null) {
          // Try to get medium quality image
          final imageMap = image as Map<String, dynamic>;
          thumbUrl =
              imageMap['medium']?.toString() ?? imageMap['small']?.toString();
          // Convert protocol-relative URLs
          if (thumbUrl != null && thumbUrl.startsWith('//')) {
            thumbUrl = 'https:$thumbUrl';
          }
        }
        results.add(OnlineTrack(
          id: 'jio_$id',
          title: title,
          artist: artist,
          duration: duration,
          thumbnailUrl: thumbUrl,
          source: MusicSourceType.jiosaavn,
        ));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    try {
      final songId = track.id.replaceFirst('jio_', '');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_songUrl$songId');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent',
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final songData = data[songId] as Map<String, dynamic>?;
      if (songData == null) return null;
      final url = songData['media_url']?.toString();
      return url;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
