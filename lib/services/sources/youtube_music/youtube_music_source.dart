import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../music_source.dart';

/// IOS_MUSIC client context constants
class YouTubeMusicClient {
  static const String clientName = 'IOS_MUSIC';
  static const String clientVersion = '5.26.1';
  static const String apiKey = 'AIzaSyBAETezhkwP0ZWA02RsqT1zu78Fpt0bC_s';
  static const String baseUrl = 'https://www.youtube.com/youtubei/v1';

  static const String userAgent =
      'com.google.ios.youtube.music/5.26.1 (iPhone15,2; U; CPU iOS 17_0 like Mac OS X)';

  static const Map<String, dynamic> clientContext = {
    'client': {
      'clientName': clientName,
      'clientVersion': clientVersion,
      'hl': 'en',
      'gl': 'US',
      'osName': 'iOS',
      'osVersion': '17.0',
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone15,2',
      'userAgent': userAgent,
      'clientScreen': 'MUSIC_PLAYBACK',
    },
  };

  static Map<String, dynamic> buildRequestBody(Map<String, dynamic> payload) {
    return {
      ...clientContext,
      ...payload,
    };
  }
}

/// YouTube Music API service using IOS_MUSIC client context
/// App Store uyumlu: Sadece IOS_MUSIC client context kullanır,
/// Android spoofing veya web signature deciphering YOK.
class YouTubeMusicSource {
  static final YouTubeMusicSource _instance = YouTubeMusicSource._internal();
  factory YouTubeMusicSource() => _instance;
  YouTubeMusicSource._internal();

  static const String _playerEndpoint = '${YouTubeMusicClient.baseUrl}/player';
  static const String _browseEndpoint = '${YouTubeMusicClient.baseUrl}/browse';
  static const String _searchEndpoint = '${YouTubeMusicClient.baseUrl}/search';
  static const String _nextEndpoint = '${YouTubeMusicClient.baseUrl}/next';

  final http.Client _client = http.Client();

  /// Build headers for IOS_MUSIC client
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'User-Agent': YouTubeMusicClient.userAgent,
        'X-Goog-Api-Key': YouTubeMusicClient.apiKey,
        'X-Goog-AuthUser': '0',
      };

  /// Generic POST request to YouTube InnerTube API
  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final requestBody = YouTubeMusicClient.buildRequestBody(body);
      final response = await http.post(
        Uri.parse(endpoint),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('YouTubeMusicSource: HTTP ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('YouTubeMusicSource error: $e');
    }
    return null;
  }

  /// Get player response (stream URL, metadata, etc.)
  Future<Map<String, dynamic>?> getPlayer(String videoId) async {
    return _post(_playerEndpoint, {
      'videoId': videoId,
      'playbackContext': {
        'contentPlaybackContext': {
          'html5Preference': 'HTML5_PREFERENCE_WANTS',
        },
      },
      'contentCheckOk': true,
      'racyCheckOk': true,
    });
  }

  /// Search YouTube Music
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 20,
    String filter = 'songs', // songs, videos, albums, artists, playlists
  }) async {
    final response = await _post(_searchEndpoint, {
      'query': query,
      'params': _getSearchParams(filter),
    });

    if (response == null) return [];

    final contents = response['contents']?['tabbedSearchResultsRenderer']?['tabs'];
    if (contents == null) return [];

    for (final tab in contents) {
      final tabRenderer = tab['tabRenderer'];
      if (tabRenderer == null) continue;
      final content = tabRenderer['content'];
      if (content == null) continue;

      final sectionList = content['sectionListRenderer'];
      if (sectionList == null) continue;

      final sections = sectionList['contents'] as List?;
      if (sections == null) continue;

      for (final section in sections) {
        final itemSection = section['itemSectionRenderer'];
        if (itemSection == null) continue;
        final contents = itemSection['contents'] as List?;
        if (contents == null) continue;

        return contents
            .where((c) => c['musicResponsiveListItemRenderer'] != null ||
                          c['musicTwoRowItemRenderer'] != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    }
    return [];
  }

  Map<String, String> _getSearchParams(String filter) {
    switch (filter) {
      case 'songs':
        return {'sp': 'EgWKAQIIAWoKEAMQBBAHEAAQBQ%3D%3D'};
      case 'videos':
        return {'sp': 'EgIQAQ%3D%3D'};
      case 'albums':
        return {'sp': 'EgWKAQIIAWoKEAMQBRAHEAAQBQ%3D%3D'};
      case 'artists':
        return {'sp': 'EgWKAQIIAWoKEAMQBhAHEAAQBQ%3D%3D'};
      case 'playlists':
        return {'sp': 'EgWKAQIIAWoKEAMQBxAHEAAQBQ%3D%3D'};
      default:
        return {};
    }
  }

  /// Get next items for continuation (radio, playlist, album)
  Future<Map<String, dynamic>?> next(String endpoint, String? continuation) async {
    return _post(_nextEndpoint, {
      'endpoint': endpoint,
      'continuation': continuation,
    });
  }

  /// Browse endpoint (albums, artists, playlists, home)
  Future<Map<String, dynamic>?> browse(String browseId, {String? continuation}) async {
    return _post(_browseEndpoint, {
      'browseId': browseId,
      if (continuation != null) 'continuation': continuation,
    });
  }

  /// Get watch playlist (radio/continuation from a seed track)
  Future<Map<String, dynamic>?> getWatchPlaylist(String videoId) async {
    return _post(_nextEndpoint, {
      'endpoint': 'watch_endpoint/$videoId',
    });
  }

  /// Get album details
  Future<Map<String, dynamic>?> getAlbum(String albumId) async {
    return browse('MPREb_$albumId');
  }

  /// Get artist details
  Future<Map<String, dynamic>?> getArtist(String artistId) async {
    return browse(artistId);
  }

  /// Get playlist details
  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    return browse('VL$playlistId');
  }

  /// Get home feed
  Future<Map<String, dynamic>?> getHome({String? continuation}) async {
    return browse('FEmusic_home', continuation: continuation);
  }

  /// Get explore feed
  Future<Map<String, dynamic>?> getExplore({String? continuation}) async {
    return browse('FEmusic_explore', continuation: continuation);
  }

  /// Get library (liked songs, playlists, etc.) - requires auth
  Future<Map<String, dynamic>?> getLibrary(String libraryId, {String? continuation}) async {
    return browse(libraryId, continuation: continuation);
  }

  void dispose() {
    _client.close();
  }
}

/// Singleton instance
final youtubeMusicSource = YouTubeMusicSource();