import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LastFmService {
  LastFmService._();
  static final LastFmService _instance = LastFmService._();
  factory LastFmService() => _instance;
  static LastFmService get instance => _instance;

  static const String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';
  static const String _apiKey = 'YOUR_LASTFM_API_KEY';

  Future<List<Map<String, String>>> getSimilarArtists(String artist, {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'method': 'artist.getSimilar',
          'artist': artist,
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.toString(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final artists = data['similarartists']?['artist'] as List?;
      if (artists == null) return [];

      return artists
          .whereType<Map<String, dynamic>>()
          .map((a) => {'name': a['name'] as String? ?? ''})
          .where((a) => a['name']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Last.fm similar artists error: $e');
      return [];
    }
  }

  Future<List<String>> getTopArtistsByTag(String tag, {int limit = 15}) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'method': 'tag.getTopArtists',
          'tag': tag,
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.toString(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final artists = data['topartists']?['artist'] as List?;
      if (artists == null) return [];

      return artists
          .whereType<Map<String, dynamic>>()
          .map((a) => a['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Last.fm top artists by tag error: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getSimilarTracks(String artist, String track, {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'method': 'track.getSimilar',
          'artist': artist,
          'track': track,
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.toString(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final tracks = data['similartracks']?['track'] as List?;
      if (tracks == null) return [];

      return tracks
          .whereType<Map<String, dynamic>>()
          .map((t) => {
            'title': t['name'] as String? ?? '',
            'artist': t['artist']?['name'] as String? ?? '',
          })
          .where((t) => t['title']!.isNotEmpty && t['artist']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Last.fm similar tracks error: $e');
      return [];
    }
  }

  Future<String?> getArtistImage(String artist) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'method': 'artist.getInfo',
          'artist': artist,
          'api_key': _apiKey,
          'format': 'json',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final images = data['artist']?['image'] as List?;
      if (images == null) return null;

      final large = images.firstWhere(
        (img) => img['size'] == 'extralarge',
        orElse: () => images.last,
      );
      return large['#text'] as String?;
    } catch (e) {
      debugPrint('Last.fm artist image error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTopTracks(String artist, {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'method': 'artist.getTopTracks',
          'artist': artist,
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.toString(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final tracks = data['toptracks']?['track'] as List?;
      if (tracks == null) return [];

      return tracks
          .whereType<Map<String, dynamic>>()
          .map((t) => {
            'name': t['name'] as String? ?? '',
            'duration': t['duration'] as int? ?? 0,
            'listeners': t['listeners'] as String? ?? '0',
            'url': t['url'] as String? ?? '',
          })
          .toList();
    } catch (e) {
      debugPrint('Last.fm top tracks error: $e');
      return [];
    }
  }

  Future<void> scrobble({
    required String artist,
    required String track,
    required String album,
    required int timestamp,
    required int duration,
  }) async {
    if (_apiKey == 'YOUR_LASTFM_API_KEY') return;

    try {
      await http.post(
        Uri.parse(_baseUrl),
        body: {
          'method': 'track.scrobble',
          'api_key': _apiKey,
          'artist': artist,
          'track': track,
          'album': album,
          'timestamp': timestamp.toString(),
          'duration': duration.toString(),
          'format': 'json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Last.fm scrobble error: $e');
    }
  }

  Future<void> nowPlaying({
    required String artist,
    required String track,
    required String album,
    required int duration,
  }) async {
    if (_apiKey == 'YOUR_LASTFM_API_KEY') return;

    try {
      await http.post(
        Uri.parse(_baseUrl),
        body: {
          'method': 'track.updateNowPlaying',
          'api_key': _apiKey,
          'artist': artist,
          'track': track,
          'album': album,
          'duration': duration.toString(),
          'format': 'json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Last.fm now playing error: $e');
    }
  }
}