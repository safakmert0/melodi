import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/spotify_service.dart';
import '../services/database_service.dart';

class ScrobbleItem {
  final String videoId;
  final String? spotifyTrackId;
  final String title;
  final String artists;
  final DateTime scrobbledAt;

  const ScrobbleItem({
    required this.videoId,
    this.spotifyTrackId,
    required this.title,
    required this.artists,
    required this.scrobbledAt,
  });

  factory ScrobbleItem.fromDb(Map<String, dynamic> row,
      {String title = '', String artists = ''}) {
    return ScrobbleItem(
      videoId: row['videoId'] as String,
      spotifyTrackId: row['spotifyTrackId'] as String?,
      title: title,
      artists: artists,
      scrobbledAt: DateTime.parse(row['scrobbledAt'] as String),
    );
  }
}

class ScrobbleService {
  final SpotifyService spotify;
  Timer? _autoScrobbleTimer;
  bool _isProcessing = false;

  ScrobbleService({required this.spotify});

  bool get isProcessing => _isProcessing;

  void dispose() {
    stopAutoScrobble();
  }

  Future<SpotifyTrackItem?> scrobbleToSpotify(
      String videoId, String title, String artist) async {
    if (!spotify.isConnected) return null;

    final db = DatabaseService.instance;
    final alreadyScrobbled = await db.getSetting('scrobble_$videoId');
    if (alreadyScrobbled != null) return null;

    final query = '$title ${artist.split(',').first}';
    final results = await spotify.searchTracks(query, limit: 3);
    if (results.isEmpty) return null;

    final matched = results.first;
    await db.insertScrobble(videoId, matched.id);

    return matched;
  }

  Future<int> processRecentSpotifyHistory() async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    try {
      final recent = await getRecentlyPlayedSpotify(limit: 20);
      if (recent.isEmpty) return 0;

      int scrobbled = 0;

      for (final track in recent) {
        // Note: Can't scrobble to YouTube Music without YTMusicService
        // This would require backend API
        scrobbled++;
      }

      return scrobbled;
    } catch (e) {
      debugPrint('processRecentHistory error: $e');
      return 0;
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<SpotifyTrackItem>> getRecentlyPlayedSpotify(
      {int limit = 20}) async {
    if (!spotify.isConnected) return [];

    try {
      if (spotify.isExpiringSoon) {
        await spotify.refreshAccessToken();
      }

      final url =
          '${SpotifyAuthConfig.webApiBase}/me/player/recently-played?limit=$limit';
      final client = http.Client();
      try {
        var response = await client.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer ${spotify.accessToken}',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 401) {
          final refreshed = await spotify.refreshAccessToken();
          if (refreshed != null) {
            response = await client.get(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer ${refreshed.accessToken}',
                'Accept': 'application/json',
              },
            );
          }
        }

        if (response.statusCode != 200) return [];

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final items = body['items'] as List<dynamic>? ?? [];

        return items
            .map((element) {
              try {
                final wrapper = element as Map<String, dynamic>;
                final trackObj = wrapper['track'] as Map<String, dynamic>?;
                if (trackObj == null) return null;

                final id = trackObj['id'] as String?;
                final name = trackObj['name'] as String?;
                if (id == null || name == null) return null;

                final artists = (trackObj['artists'] as List<dynamic>?)
                        ?.map((a) =>
                            (a as Map<String, dynamic>)['name'] as String? ??
                            '')
                        .where((a) => a.isNotEmpty)
                        .toList() ??
                    [];

                final albumObj = trackObj['album'] as Map<String, dynamic>?;
                final albumName = albumObj?['name'] as String?;

                return SpotifyTrackItem(
                  id: id,
                  name: name,
                  artists: artists,
                  albumName: albumName,
                  durationMs: trackObj['duration_ms'] as int? ?? 0,
                  uri: trackObj['uri'] as String? ?? 'spotify:track:$id',
                );
              } catch (_) {
                return null;
              }
            })
            .where((e) => e != null)
            .cast<SpotifyTrackItem>()
            .toList();
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('getRecentlyPlayedSpotify error: $e');
      return [];
    }
  }

  void startAutoScrobble(int intervalMinutes) {
    stopAutoScrobble();
    _autoScrobbleTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => processRecentSpotifyHistory(),
    );
  }

  void stopAutoScrobble() {
    _autoScrobbleTimer?.cancel();
    _autoScrobbleTimer = null;
  }
}