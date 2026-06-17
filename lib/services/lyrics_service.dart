import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LyricsService {
  static const _baseUrl = 'https://lrclib.net/api';

  static Future<String?> fetchLyrics({
    required String artist,
    required String track,
    String? album,
  }) async {
    try {
      final params = {
        'artist_name': artist,
        'track_name': track,
      };
      if (album != null && album.isNotEmpty) {
        params['album_name'] = album;
      }
      final uri = Uri.parse('$_baseUrl/get')
          .replace(queryParameters: params);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/1.0');
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final raw = data['lyrics'] as String?;
        if (raw != null && raw.isNotEmpty) return raw;
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) return synced;
        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) return plain;
      }
      return null;
    } catch (e) {
      debugPrint('Lyrics fetch error: $e');
      return null;
    }
  }

  static Future<String?> searchLyrics(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {'q': query});
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/1.0');
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as List;
        if (data.isEmpty) return null;
        final first = data.first as Map<String, dynamic>;
        final raw = first['lyrics'] as String?;
        if (raw != null && raw.isNotEmpty) return raw;
        final synced = first['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) return synced;
        return first['plainLyrics'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Lyrics search error: $e');
      return null;
    }
  }
}
