import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ArtworkService {
  static const _itunesSearchUrl = 'https://itunes.apple.com/search';

  static Future<Uint8List?> fetchArtwork({
    required String artist,
    required String album,
  }) async {
    try {
      final uri = Uri.parse(_itunesSearchUrl).replace(
        queryParameters: {
          'term': '$artist $album',
          'entity': 'album',
          'limit': '5',
          'country': 'US',
        },
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      for (final result in results) {
        final artUrl = result['artworkUrl100'] as String?;
        if (artUrl == null) continue;
        final largeUrl = artUrl.replaceAll('100x100', '600x600');
        return _downloadImage(largeUrl);
      }
      return null;
    } catch (e) {
      debugPrint('Artwork fetch error: $e');
      return null;
    }
  }

  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(),
        (b, chunk) => b..add(chunk),
      );
      return bytes.takeBytes();
    } catch (e) {
      debugPrint('Image download error: $e');
      return null;
    }
  }
}
