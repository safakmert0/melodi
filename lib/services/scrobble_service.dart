import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/ytmusic_service.dart';
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

  factory ScrobbleItem.fromDb(Map<String, dynamic> row, {String title = '', String artists = ''}) {
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
  final YTMusicService ytmusic;
  final SpotifyService spotify;
  Timer? _autoScrobbleTimer;
  bool _isProcessing = false;

  ScrobbleService({required this.ytmusic, required this.spotify});

  bool get isProcessing => _isProcessing;

  void dispose() {
    stopAutoScrobble();
  }

  Future<List<YTMusicTrack>> getYtMusicHistory() async {
    if (!ytmusic.client.isAuthenticated) return [];

    const historyBrowseId = 'FEmusic_history';
    final response = await ytmusic.client.browse(historyBrowseId);
    if (response == null) return [];

    final tracks = <YTMusicTrack>[];
    final contents = _navigatePath(response, [
      'contents', 'singleColumnBrowseResultsRenderer', 'tabs',
    ]);
    if (contents == null) return [];

    final tab = (contents as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .map((e) => e['tabRenderer'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .firstOrNull;
    if (tab == null) return [];

    final sections = _navigatePath(tab, ['content', 'sectionListRenderer', 'contents']);
    if (sections == null) return [];

    for (final section in (sections as List<dynamic>).map((e) => e as Map<String, dynamic>)) {
      final shelf = section['musicShelfRenderer'] as Map<String, dynamic>?;
      if (shelf == null) continue;
      final items = shelf['contents'] as List<dynamic>?;
      if (items == null) continue;

      for (final item in items) {
        final renderer = (item as Map<String, dynamic>)
            ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
        if (renderer == null) continue;
        final track = _parseTrackFromRenderer(renderer);
        if (track != null) tracks.add(track);
      }
    }

    return tracks;
  }

  dynamic _navigatePath(Map<String, dynamic> obj, List<String> keys) {
    dynamic current = obj;
    for (final key in keys) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  YTMusicTrack? _parseTrackFromRenderer(Map<String, dynamic> renderer) {
    final videoId = _extractVideoId(renderer);
    if (videoId == null) return null;

    final flexColumns = renderer['flexColumns'] as List<dynamic>?;
    if (flexColumns == null || flexColumns.isEmpty) return null;

    final titleCol = (flexColumns[0] as Map<String, dynamic>?)
        ?.let((c) => c['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>?);
    final title = _extractText(titleCol);
    if (title == null) return null;

    final artistCol = flexColumns.length > 1
        ? (flexColumns[1] as Map<String, dynamic>?)
            ?.let((c) => c['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>?)
        : null;
    final artistRuns = _extractArtistRuns(artistCol);
    final artists = artistRuns.join(', ');

    return YTMusicTrack(
      videoId: videoId,
      title: title,
      artists: artists,
    );
  }

  String? _extractVideoId(Map<String, dynamic> renderer) {
    final fromData = (renderer['playlistItemData'] as Map<String, dynamic>?)
        ?.let((d) => d['videoId'] as String?);
    if (fromData != null) return fromData;

    return _navigatePath(renderer, [
      'overlay', 'musicItemThumbnailOverlayRenderer', 'content',
      'musicPlayButtonRenderer', 'playNavigationEndpoint', 'watchEndpoint', 'videoId',
    ]);
  }

  String? _extractText(Map<String, dynamic>? runsContainer) {
    if (runsContainer == null) return null;
    final runs = runsContainer['runs'] as List<dynamic>?;
    if (runs == null || runs.isEmpty) return null;
    return (runs.first as Map<String, dynamic>)['text'] as String?;
  }

  List<String> _extractArtistRuns(Map<String, dynamic>? flexColumn) {
    if (flexColumn == null) return [];
    final runs = flexColumn['runs'] as List<dynamic>?;
    if (runs == null) return [];
    return runs
        .map((r) => (r as Map<String, dynamic>)['text'] as String? ?? '')
        .where((t) => t != ' & ' && t != ', ' && t != ' x ')
        .toList();
  }

  Future<SpotifyTrackItem?> scrobbleToSpotify(String videoId, String title, String artist) async {
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

  Future<int> processRecentHistory() async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    try {
      final history = await getYtMusicHistory();
      if (history.isEmpty) return 0;

      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      int scrobbled = 0;

      for (final track in history) {
        final result = await scrobbleToSpotify(
          track.videoId,
          track.title,
          track.artists,
        );
        if (result != null) scrobbled++;
      }

      return scrobbled;
    } catch (e) {
      debugPrint('processRecentHistory error: $e');
      return 0;
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<SpotifyTrackItem>> getRecentlyPlayedSpotify({int limit = 20}) async {
    if (!spotify.isConnected) return [];

    try {
      if (spotify.isExpiringSoon) {
        await spotify.refreshAccessToken();
      }

      final url = '${SpotifyAuthConfig.webApiBase}/me/player/recently-played?limit=$limit';
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

        return items.map((element) {
          try {
            final wrapper = element as Map<String, dynamic>;
            final trackObj = wrapper['track'] as Map<String, dynamic>?;
            if (trackObj == null) return null;

            final id = trackObj['id'] as String?;
            final name = trackObj['name'] as String?;
            if (id == null || name == null) return null;

            final artists = (trackObj['artists'] as List<dynamic>?)
                    ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
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
        }).where((e) => e != null).cast<SpotifyTrackItem>().toList();
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
      (_) => processRecentHistory(),
    );
  }

  void stopAutoScrobble() {
    _autoScrobbleTimer?.cancel();
    _autoScrobbleTimer = null;
  }
}

extension _LetExtension<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
