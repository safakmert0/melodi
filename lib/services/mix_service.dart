import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'spotify_service.dart';

class MixService {
  final SpotifyService _spotifyService;

  MixService({required SpotifyService spotifyService})
      : _spotifyService = spotifyService;

  Future<List<Map<String, dynamic>>> getDailyMix() async {
    try {
      final cached = await _getCachedMix('daily_mix');
      if (cached != null) return cached;

      final token = await _spotifyService.getClientCredentialsToken();
      if (token == null) return [];

      List<String> seedTracks = [];
      if (_spotifyService.isConnected) {
        final liked = await _spotifyService.getLikedSongs(limit: 50);
        seedTracks = liked
            .where((t) => t.id.isNotEmpty)
            .take(5)
            .map((t) => t.id)
            .toList();
      }

      final result = seedTracks.isNotEmpty
          ? await _fetchRecommendations(token, seedTracks: seedTracks)
          : await _fetchRecommendations(token,
              seedGenres: 'pop,rock,electronic,indie');

      if (result.isNotEmpty) {
        await _cacheMix('daily_mix', result);
      }
      return result;
    } catch (e) {
      debugPrint('getDailyMix failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReleaseRadar() async {
    try {
      final cached = await _getCachedMix('release_radar');
      if (cached != null) return cached;

      final token = await _spotifyService.getClientCredentialsToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(
            '${SpotifyAuthConfig.webApiBase}/browse/new-releases?limit=20&country=US'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final albums = body['albums']?['items'] as List<dynamic>? ?? [];

      final result = <Map<String, dynamic>>[];
      for (final album in albums) {
        final a = album as Map<String, dynamic>;
        final albumId = a['id'] as String?;
        if (albumId == null) continue;

        final tracksResponse = await http.get(
          Uri.parse(
              '${SpotifyAuthConfig.webApiBase}/albums/$albumId/tracks?limit=1&market=US'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (tracksResponse.statusCode != 200) continue;

        final tracksBody =
            jsonDecode(tracksResponse.body) as Map<String, dynamic>;
        final trackItems = tracksBody['items'] as List<dynamic>? ?? [];
        if (trackItems.isEmpty) continue;

        final track = trackItems.first as Map<String, dynamic>;
        final images = a['images'] as List<dynamic>?;
        result.add({
          'id': track['id'] as String? ?? '',
          'title': track['name'] as String? ?? '',
          'artist': (a['artists'] as List<dynamic>?)
                  ?.map(
                      (ar) => (ar as Map<String, dynamic>)['name'] as String?)
                  .join(', ') ??
              '',
          'album': a['name'] as String? ?? '',
          'imageUrl': (images != null && images.isNotEmpty)
              ? (images.first as Map<String, dynamic>)['url'] as String?
              : null,
          'albumArt': null,
          'durationMs': track['duration_ms'] as int? ?? 0,
        });
      }

      if (result.isNotEmpty) {
        await _cacheMix('release_radar', result);
      }
      return result;
    } catch (e) {
      debugPrint('getReleaseRadar failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDiscoverWeekly() async {
    try {
      final cached = await _getCachedMix('discover_weekly');
      if (cached != null) return cached;

      final token = await _spotifyService.getClientCredentialsToken();
      if (token == null) return [];

      final result = await _fetchRecommendations(token,
          seedGenres: 'pop,rock,electronic,hip-hop,indie');

      if (result.isNotEmpty) {
        await _cacheMix('discover_weekly', result);
      }
      return result;
    } catch (e) {
      debugPrint('getDiscoverWeekly failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTasteMatch(String userId) async {
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchRecommendations(
    String token, {
    List<String>? seedArtists,
    List<String>? seedTracks,
    String? seedGenres,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'market': 'US',
    };
    if (seedArtists != null && seedArtists.isNotEmpty) {
      params['seed_artists'] = seedArtists.join(',');
    }
    if (seedTracks != null && seedTracks.isNotEmpty) {
      params['seed_tracks'] = seedTracks.join(',');
    }
    if (seedGenres != null && seedGenres.isNotEmpty) {
      params['seed_genres'] = seedGenres;
    }

    final uri = Uri.parse('${SpotifyAuthConfig.webApiBase}/recommendations')
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tracks = body['tracks'] as List<dynamic>? ?? [];
    return tracks.map((t) => _parseTrack(t as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _parseTrack(Map<String, dynamic> track) {
    final album = track['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List<dynamic>?;
    return {
      'id': track['id'] as String? ?? '',
      'title': track['name'] as String? ?? '',
      'artist': (track['artists'] as List<dynamic>?)
              ?.map(
                  (a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
              .join(', ') ??
          '',
      'album': album?['name'] as String? ?? '',
      'imageUrl': (images != null && images.isNotEmpty)
          ? (images.first as Map<String, dynamic>)['url'] as String?
          : null,
      'albumArt': null,
      'durationMs': track['duration_ms'] as int? ?? 0,
    };
  }

  Future<void> _cacheMix(
      String mixType, List<Map<String, dynamic>> data) async {
    final db = DatabaseService.instance;
    await db.cacheMix(mixType, jsonEncode(data));
  }

  Future<List<Map<String, dynamic>>?> _getCachedMix(String mixType) async {
    final db = DatabaseService.instance;
    final cached = await db.getCachedMix(mixType);
    if (cached == null) return null;

    final generatedAt = cached['generatedAt'] as String?;
    if (generatedAt == null) return null;

    final generated = DateTime.parse(generatedAt);
    if (DateTime.now().difference(generated).inHours >= 24) return null;

    final dataStr = cached['data'] as String?;
    if (dataStr == null) return null;

    final decoded = jsonDecode(dataStr) as List<dynamic>;
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }
}
