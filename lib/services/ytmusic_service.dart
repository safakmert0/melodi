import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'track_matcher.dart';

class YTMusicTrack {
  final String videoId;
  final String title;
  final String artists;
  final String? album;
  final int? durationMs;
  final String? thumbnailUrl;

  const YTMusicTrack({
    required this.videoId,
    required this.title,
    required this.artists,
    this.album,
    this.durationMs,
    this.thumbnailUrl,
  });

  factory YTMusicTrack.fromJson(Map<String, dynamic> json) {
    return YTMusicTrack(
      videoId: json['videoId'] as String,
      title: json['title'] as String,
      artists: json['artists'] as String? ?? '',
      album: json['album'] as String?,
      durationMs: json['durationMs'] as int?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artists': artists,
        'album': album,
        'durationMs': durationMs,
        'thumbnailUrl': thumbnailUrl,
      };
}

class YTMusicPlaylist {
  final String playlistId;
  final String title;
  final String? thumbnailUrl;
  final int? trackCount;

  const YTMusicPlaylist({
    required this.playlistId,
    required this.title,
    this.thumbnailUrl,
    this.trackCount,
  });

  factory YTMusicPlaylist.fromJson(Map<String, dynamic> json) {
    return YTMusicPlaylist(
      playlistId: json['playlistId'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      trackCount: json['trackCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'playlistId': playlistId,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'trackCount': trackCount,
      };
}

class YTMusicSession {
  final String? cookie;
  final String? accessToken;
  final int expiresAtEpoch;
  final String? username;

  const YTMusicSession({
    this.cookie,
    this.accessToken,
    this.expiresAtEpoch = 0,
    this.username,
  });

  bool get isConnected => cookie != null || accessToken != null;
}

class InnerTubeClient {
  static const String baseUrl = 'https://www.youtube.com/youtubei/v1';
  static const String musicBaseUrl = 'https://music.youtube.com/youtubei/v1';
  static const String clientName = 'WEB_REMIX';
  static const String clientVersion = '1.20250304.00.00';
  static const String apiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  String? _cookie;
  String? _sapiSid;
  String? _authHeader;

  InnerTubeClient({String? cookie}) {
    if (cookie != null) setCookie(cookie);
  }

  bool get isAuthenticated => _sapiSid != null;

  void setCookie(String cookie) {
    _cookie = cookie;
    _sapiSid = _extractSapiSid(cookie);
    _authHeader = _sapiSid != null ? _generateAuthHeader(_sapiSid!) : null;
  }

  void clearCookie() {
    _cookie = null;
    _sapiSid = null;
    _authHeader = null;
  }

  String? _extractSapiSid(String cookie) {
    for (final name in ['__Secure-3PSAPISID', '__Secure-1PSAPISID', 'SAPISID']) {
      final regex = RegExp('$name=([^;]+)');
      final match = regex.firstMatch(cookie);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String _generateAuthHeader(String sapiSid) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final hash = sha1.convert(utf8.encode('$timestamp $sapiSid')).toString();
    return 'SAPISIDHASH ${timestamp}_$hash';
  }

  Map<String, dynamic> _buildContext() {
    return {
      'client': {
        'clientName': clientName,
        'clientVersion': clientVersion,
        'hl': 'en',
        'gl': 'US',
      },
      'user': {},
    };
  }

  Future<Map<String, dynamic>?> _executeRequest({
    required String url,
    required Map<String, dynamic> body,
    bool authenticated = false,
    bool useMusicBase = true,
  }) async {
    final base = useMusicBase ? musicBaseUrl : baseUrl;
    final separator = url.contains('?') ? '&' : '?';
    final apiKeyParam = authenticated || !useMusicBase ? '' : '&key=$apiKey';
    final fullUrl = '$base/$url${separator}prettyPrint=false$apiKeyParam';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(Uri.parse(fullUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('User-Agent', userAgent);
      request.headers.set('X-YouTube-Client-Name', '67');
      request.headers.set('X-YouTube-Client-Version', clientVersion);
      request.headers.set('Origin', 'https://music.youtube.com');
      request.headers.set('Referer', 'https://music.youtube.com/');

      if (authenticated && _cookie != null && _authHeader != null) {
        request.headers.set('Cookie', _cookie!);
        request.headers.set('Authorization', _authHeader!);
        request.headers.set('X-Goog-AuthUser', '0');
      }

      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 401) {
        debugPrint('InnerTube: 401 received, clearing auth cache');
        clearCookie();
        return null;
      }

      if (response.statusCode != 200) {
        debugPrint('InnerTube: HTTP ${response.statusCode} for $url');
        return null;
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('InnerTube request failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>?> browse(String browseId) async {
    return _executeRequest(
      url: 'browse',
      body: {
        'context': _buildContext(),
        'browseId': browseId,
      },
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>?> browseContinuation(String continuation) async {
    return _executeRequest(
      url: 'browse?ctoken=$continuation&continuation=$continuation&type=next',
      body: {
        'context': _buildContext(),
      },
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>?> next(String videoId) async {
    return _executeRequest(
      url: 'next',
      body: {
        'context': _buildContext(),
        'videoId': videoId,
      },
    );
  }

  Future<Map<String, dynamic>?> search(String query, {String? params}) async {
    final body = <String, dynamic>{
      'context': _buildContext(),
      'query': query,
    };
    if (params != null) body['params'] = params;
    return _executeRequest(
      url: 'search',
      body: body,
    );
  }

  Future<bool> likeVideo(String videoId, {bool like = true}) async {
    final endpoint = like ? 'like/like' : 'like/removelike';
    final result = await _executeRequest(
      url: endpoint,
      body: {
        'context': _buildContext(),
        'target': {'videoId': videoId},
      },
      authenticated: true,
      useMusicBase: false,
    );
    return result != null;
  }

  Future<Map<String, dynamic>?> player(String videoId) async {
    return _executeRequest(
      url: 'player',
      body: {
        'context': _buildContext(),
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      },
      useMusicBase: false,
    );
  }
}

class YTMusicService {
  final InnerTubeClient client;
  String? _cookie;

  YTMusicService({InnerTubeClient? client})
      : client = client ?? InnerTubeClient();

  bool get isConnected => _cookie != null;
  String? get cookie => _cookie;

  void connectWithCookie(String cookie) {
    _cookie = cookie;
    client.setCookie(cookie);
  }

  void disconnect() {
    _cookie = null;
    client.clearCookie();
  }

  int? _parseDurationToMs(String? duration) {
    if (duration == null) return null;
    final parts = duration.split(':').map((e) => int.tryParse(e)).toList();
    if (parts.length == 2 && parts[0] != null && parts[1] != null) {
      return (parts[0]! * 60 + parts[1]!) * 1000;
    }
    if (parts.length == 3 && parts[0] != null && parts[1] != null && parts[2] != null) {
      return (parts[0]! * 3600 + parts[1]! * 60 + parts[2]!) * 1000;
    }
    return null;
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

  String? _extractVideoId(Map<String, dynamic> renderer) {
    final fromData = (renderer['playlistItemData'] as Map<String, dynamic>?)
        ?.let((d) => d['videoId'] as String?);
    if (fromData != null) return fromData;

    return _navigatePath(renderer, [
      'overlay', 'musicItemThumbnailOverlayRenderer', 'content',
      'musicPlayButtonRenderer', 'playNavigationEndpoint', 'watchEndpoint', 'videoId',
    ]);
  }

  String? _pickThumbnailUrl(Map<String, dynamic>? thumbnails) {
    if (thumbnails == null) return null;
    final list = thumbnails['thumbnails'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    final best = list.map((e) => e as Map<String, dynamic>).reduce(
      (a, b) => (a['width'] as int? ?? 0) > (b['width'] as int? ?? 0) ? a : b,
    );
    return best['url'] as String?;
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

    String? album;
    if (flexColumns.length > 2) {
      final albumCol = (flexColumns[2] as Map<String, dynamic>?)
          ?.let((c) => c['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>?);
      album = _extractText(albumCol);
    }

    final fixedColumns = renderer['fixedColumns'] as List<dynamic>?;
    String? durationText;
    if (fixedColumns != null && fixedColumns.isNotEmpty) {
      final fixedCol = (fixedColumns.first as Map<String, dynamic>?)
          ?.let((c) => c['musicResponsiveListItemFixedColumnRenderer'] as Map<String, dynamic>?);
      durationText = _extractText(fixedCol);
    }
    final durationMs = _parseDurationToMs(durationText);

    final thumbnail = renderer['thumbnail'] as Map<String, dynamic>?;
    String? thumbnailUrl;
    if (thumbnail != null) {
      final musicThumbnail = thumbnail['musicThumbnailRenderer'] as Map<String, dynamic>?;
      if (musicThumbnail != null) {
        thumbnailUrl = _pickThumbnailUrl(musicThumbnail['thumbnail'] as Map<String, dynamic>?);
      }
    }

    return YTMusicTrack(
      videoId: videoId,
      title: title,
      artists: artists,
      album: album,
      durationMs: durationMs,
      thumbnailUrl: thumbnailUrl,
    );
  }

  List<YTMusicTrack> _parseTracksFromBrowse(Map<String, dynamic> response) {
    final tracks = <YTMusicTrack>[];

    final twoColumn = _navigatePath(response, [
      'contents', 'twoColumnBrowseResultsRenderer',
      'secondaryContents', 'sectionListRenderer', 'contents',
    ]);
    if (twoColumn != null) {
      final shelf = (twoColumn as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .where((e) => e.containsKey('musicPlaylistShelfRenderer'))
          .map((e) => e['musicPlaylistShelfRenderer'] as Map<String, dynamic>)
          .firstOrNull;
      if (shelf != null) {
        final items = shelf['contents'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            final renderer = (item as Map<String, dynamic>)
                ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
            if (renderer == null) continue;
            final track = _parseTrackFromRenderer(renderer);
            if (track != null) tracks.add(track);
          }
          return tracks;
        }
      }
    }

    final singleColumn = _navigatePath(response, [
      'contents', 'singleColumnBrowseResultsRenderer', 'tabs',
    ]);
    if (singleColumn != null) {
      final tab = (singleColumn as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => e['tabRenderer'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .firstOrNull;
      if (tab != null) {
        final sections = _navigatePath(tab, ['content', 'sectionListRenderer', 'contents']);
        if (sections != null) {
          for (final section in (sections as List<dynamic>).map((e) => e as Map<String, dynamic>)) {
            final shelfRaw = section['musicShelfRenderer'];
            if (shelfRaw == null) continue;
            final shelf = shelfRaw as Map<String, dynamic>;
            final contentsRaw = shelf['contents'];
            if (contentsRaw == null) continue;
            final items = contentsRaw as List<dynamic>;
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
      }
    }

    return tracks;
  }

  List<YTMusicTrack> _parseContinuationPage(Map<String, dynamic> response) {
    final tracks = <YTMusicTrack>[];

    final cc = response['continuationContents'] as Map<String, dynamic>?;
    if (cc != null) {
      final shelf = (cc['musicPlaylistShelfContinuation'] ?? cc['musicShelfContinuation']) as Map<String, dynamic>?;
      if (shelf != null) {
        final items = shelf['contents'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            final renderer = (item as Map<String, dynamic>)
                ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
            if (renderer == null) continue;
            final track = _parseTrackFromRenderer(renderer);
            if (track != null) tracks.add(track);
          }
          return tracks;
        }
      }
    }

    final actions = response['onResponseReceivedActions'] as List<dynamic>?;
    if (actions != null) {
      for (final action in actions) {
        final items = (action as Map<String, dynamic>)
            .let((a) => a['appendContinuationItemsAction'] as Map<String, dynamic>?)
            ?.let((a) => a['continuationItems'] as List<dynamic>?);
        if (items == null) continue;
        for (final item in items) {
          final renderer = (item as Map<String, dynamic>)
              ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;
          final track = _parseTrackFromRenderer(renderer);
          if (track != null) tracks.add(track);
        }
      }
    }

    return tracks;
  }

  String? _extractContinuationToken(Map<String, dynamic> response) {
    const paths = [
      ['continuationContents', 'musicPlaylistShelfContinuation', 'continuations'],
      ['continuationContents', 'musicShelfContinuation', 'continuations'],
    ];

    for (final path in paths) {
      final cont = _navigatePath(response, path);
      if (cont != null) {
        final token = _navigatePath(
          (cont as List<dynamic>).first as Map<String, dynamic>,
          ['nextContinuationData', 'continuation'],
        );
        if (token != null) return token;
      }
    }

    final actions = response['onResponseReceivedActions'] as List<dynamic>?;
    if (actions != null) {
      for (final action in actions) {
        final items = (action as Map<String, dynamic>)
            .let((a) => a['appendContinuationItemsAction'] as Map<String, dynamic>?)
            ?.let((a) => a['continuationItems'] as List<dynamic>?);
        if (items == null || items.isEmpty) continue;
        final last = items.last as Map<String, dynamic>;
        final token = _navigatePath(last, [
          'continuationItemRenderer', 'continuationEndpoint',
          'continuationCommand', 'token',
        ]);
        if (token != null) return token;
      }
    }

    final twoColumnContents = _navigatePath(response, [
      'contents', 'twoColumnBrowseResultsRenderer',
      'secondaryContents', 'sectionListRenderer', 'contents',
    ]);
    if (twoColumnContents != null) {
      final shelf = (twoColumnContents as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .where((e) => e.containsKey('musicPlaylistShelfRenderer'))
          .map((e) => e['musicPlaylistShelfRenderer'] as Map<String, dynamic>)
          .firstOrNull;
      if (shelf != null) {
        final items = shelf['contents'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final last = items.last as Map<String, dynamic>;
          final token = _navigatePath(last, [
            'continuationItemRenderer', 'continuationEndpoint',
            'continuationCommand', 'token',
          ]);
          if (token != null) return token;
        }
      }
    }

    return null;
  }

  Future<List<YTMusicTrack>> _collectTracksWithPagination(Map<String, dynamic> initialResponse) async {
    final allTracks = <YTMusicTrack>[];
    allTracks.addAll(_parseTracksFromBrowse(initialResponse));
    var token = _extractContinuationToken(initialResponse);
    var pages = 1;

    while (token != null && pages < 100) {
      final page = await client.browseContinuation(token);
      if (page == null) break;
      allTracks.addAll(_parseContinuationPage(page));
      token = _extractContinuationToken(page);
      pages++;
    }

    return allTracks;
  }

  Future<List<YTMusicPlaylist>> getLibraryPlaylists() async {
    const browseId = 'FEmusic_liked_playlists';
    final response = await client.browse(browseId);
    if (response == null) return [];

    final playlists = <YTMusicPlaylist>[];
    final seenIds = <String>{};

    final tabs = _navigatePath(response, [
      'contents', 'singleColumnBrowseResultsRenderer', 'tabs',
    ]);
    if (tabs == null) return [];

    for (final tab in (tabs as List<dynamic>).map((e) => e as Map<String, dynamic>)) {
      final sections = _navigatePath(tab, ['tabRenderer', 'content', 'sectionListRenderer', 'contents']);
      if (sections == null) continue;

      for (final section in (sections as List<dynamic>).map((e) => e as Map<String, dynamic>)) {
        List<dynamic>? items;

        final grid = section['gridRenderer'] as Map<String, dynamic>?;
        if (grid != null) {
          items = grid['items'] as List<dynamic>?;
        }

        final shelf = section['musicShelfRenderer'] as Map<String, dynamic>?;
        if (shelf != null && items == null) {
          items = shelf['contents'] as List<dynamic>?;
        }

        final itemSection = section['itemSectionRenderer'] as Map<String, dynamic>?;
        if (itemSection != null && items == null) {
          final contents = itemSection['contents'] as List<dynamic>?;
          if (contents != null && contents.isNotEmpty) {
            final innerGrid = (contents.first as Map<String, dynamic>)['gridRenderer'] as Map<String, dynamic>?;
            if (innerGrid != null) {
              items = innerGrid['items'] as List<dynamic>?;
            }
          }
        }

        if (items == null) continue;

        for (final item in items) {
          final renderer = (item as Map<String, dynamic>)
                  ['musicTwoRowItemRenderer'] as Map<String, dynamic>?
              ?? (item as Map<String, dynamic>)
                  ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;

          final playlist = _parsePlaylistFromRenderer(renderer);
          if (playlist != null && seenIds.add(playlist.playlistId)) {
            playlists.add(playlist);
          }
        }
      }
    }

    return playlists;
  }

  YTMusicPlaylist? _parsePlaylistFromRenderer(Map<String, dynamic> renderer) {
    final browseId = _navigatePath(renderer, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
    if (browseId == null) return null;
    if (!browseId.startsWith('VL')) return null;
    if (browseId == 'VLLM' || browseId == 'VLSE') return null;

    final playlistId = browseId.replaceFirst('VL', '');

    String? title;
    final titleRuns = renderer['title'] as Map<String, dynamic>?;
    if (titleRuns != null) {
      title = _extractText(titleRuns);
    }
    if (title == null) {
      final flexColumns = renderer['flexColumns'] as List<dynamic>?;
      if (flexColumns != null && flexColumns.isNotEmpty) {
        final col = (flexColumns.first as Map<String, dynamic>?)
            ?.let((c) => c['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>?);
        title = _extractText(col);
      }
    }
    if (title == null) return null;

    String? thumbnailUrl;
    final thumbRenderer = renderer['thumbnailRenderer'] as Map<String, dynamic>?;
    if (thumbRenderer != null) {
      final musicThumb = thumbRenderer['musicThumbnailRenderer'] as Map<String, dynamic>?;
      if (musicThumb != null) {
        thumbnailUrl = _pickThumbnailUrl(musicThumb['thumbnail'] as Map<String, dynamic>?);
      }
    }

    int? trackCount;
    final subtitle = renderer['subtitle'] as Map<String, dynamic>?;
    if (subtitle != null) {
      final runs = subtitle['runs'] as List<dynamic>?;
      if (runs != null) {
        final text = runs.map((r) => (r as Map<String, dynamic>)['text'] as String? ?? '').join();
        final match = RegExp(r'(\d+)\s+(?:songs?|tracks?)').firstMatch(text);
        if (match != null) {
          trackCount = int.tryParse(match.group(1)!);
        }
      }
    }

    return YTMusicPlaylist(
      playlistId: playlistId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      trackCount: trackCount,
    );
  }

  Future<List<YTMusicTrack>> getLibrarySongs() async {
    const browseId = 'VLLM';
    final response = await client.browse(browseId);
    if (response == null) return [];
    return _collectTracksWithPagination(response);
  }

  Future<List<YTMusicTrack>> getPlaylistTracks(String playlistId) async {
    final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final response = await client.browse(browseId);
    if (response == null) return [];
    return _collectTracksWithPagination(response);
  }

  Future<bool> rateTrack(String videoId, String rating) async {
    if (!client.isAuthenticated) return false;
    if (rating == 'LIKE') {
      return client.likeVideo(videoId, like: true);
    } else if (rating == 'INDIFFERENT') {
      return client.likeVideo(videoId, like: false);
    }
    return false;
  }

  Future<List<YTMusicTrack>> search(String query) async {
    final response = await client.search(query);
    if (response == null) return [];

    final tracks = <YTMusicTrack>[];

    final shelves = _navigatePath(response, [
      'contents', 'tabbedSearchResultsRenderer', 'tabs',
    ]);
    if (shelves == null) return [];

    final tab = (shelves as List<dynamic>)
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

      final title = _navigatePath(shelf, ['title', 'runs']);
      final titleText = title is List ? ((title as List<dynamic>).firstOrNull as Map<String, dynamic>?)?.let((t) => t['text'] as String?) : null;
      if (titleText != null && titleText != 'Songs') continue;

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

  Future<List<YTMusicTrack>> syncPlaylist(String playlistId, {String? direction}) async {
    debugPrint('YTMusicService.syncPlaylist: $playlistId direction=$direction');
    return getPlaylistTracks(playlistId);
  }

  Future<MatchResult?> searchAndMatch(
    String title,
    String artist, {
    String? album,
    int? durationMs,
  }) async {
    final matcher = TrackMatcher(search);
    return matcher.matchSpotifyTrackToYT(
      title,
      artist,
      album: album,
      durationMs: durationMs,
    );
  }
}

extension _LetExtension<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
