import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Native Dart YTMusic servis (JollyTone eşdeğeri, sunucusuz).
/// JS paketi yerine doğrudan InnerTube WEB_REMIX + ANDROID vb istemcilerle
/// arama ve indirme yapar — `flutter_js` yok, asset yok.
class YtMusicService {
  YtMusicService._();
  static final YtMusicService _instance = YtMusicService._();
  factory YtMusicService() => _instance;
  static YtMusicService get instance => _instance;

  static const String _clientVersion = '1.20240801.01.00';
  static const String _innerTubeApiKey = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';
  static const String _innerTubeClientVersion = '21.02.35';
  static const String _innerTubeUserAgent =
      'com.google.android.youtube/21.02.35 (Linux; U; Android 11) gzip';

  static const int _maxResults = 12;
  static const Duration _fetchTimeout = Duration(seconds: 15);

  static const Map<String, String> _ytSearchParams = {
    'tracks': 'EgWKAQIIAQ%3D%3D',
    'albums': 'EgWKAQIYAQ%3D%3D',
    'artists': 'EgWKAQIgAQ%3D%3D',
    'playlists': 'EgWKAQIoAQ%3D%3D',
  };

  static const List<Map<String, dynamic>> _innerTubeClients = [
    {
      'name': 'android_vr',
      'clientHeaderName': '28',
      'requiresGvsPoToken': false,
      'body': {
        'context': {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.65.10',
            'androidSdkVersion': 32,
            'hl': 'en',
            'gl': 'US',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
            'osName': 'Android',
            'osVersion': '12L',
            'platform': 'MOBILE',
            'deviceMake': 'Oculus',
            'deviceModel': 'Quest 3',
          }
        }
      },
      'ua':
          'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      'key': _innerTubeApiKey,
    },
    {
      'name': 'mweb',
      'clientHeaderName': '2',
      'requiresGvsPoToken': true,
      'body': {
        'context': {
          'client': {
            'clientName': 'MWEB',
            'clientVersion': '2.20260115.01.00',
            'hl': 'en',
            'gl': 'US',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
            'userAgent':
                'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)',
          }
        }
      },
      'ua':
          'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)',
      'key': _innerTubeApiKey,
    },
    {
      'name': 'android',
      'clientHeaderName': '3',
      'requiresGvsPoToken': true,
      'body': {
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': _innerTubeClientVersion,
            'androidSdkVersion': 30,
            'hl': 'en',
            'gl': 'US',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
            'osName': 'Android',
            'osVersion': '11',
            'platform': 'MOBILE',
          }
        }
      },
      'ua': _innerTubeUserAgent,
      'key': _innerTubeApiKey,
    },
    {
      'name': 'ios',
      'clientHeaderName': '5',
      'requiresGvsPoToken': true,
      'body': {
        'context': {
          'client': {
            'clientName': 'IOS',
            'clientVersion': '21.02.3',
            'deviceMake': 'Apple',
            'deviceModel': 'iPhone16,2',
            'hl': 'en',
            'gl': 'US',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
            'osName': 'iOS',
            'osVersion': '18.3.2',
            'platform': 'MOBILE',
          }
        }
      },
      'ua': 'com.google.ios.youtube/21.02.3 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      'key': 'AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc',
    },
  ];

  static const List<int> _audioItagPreference = [
    140, // m4a 128
    141, // m4a 256
    139, // m4a 48
    251, // opus 160
    250, // opus 70
    249, // opus 50
    171, // webm 128
  ];

  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  // ---------- Search ----------
  Future<List<Map<String, dynamic>>> search(String query,
      {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final key = 'yt:search:$trimmed:tracks';
    final cached = _cacheGet(key);
    if (cached != null) return cached;

    final results = await _performSearch(trimmed, _ytSearchParams['tracks']);
    final sanitized = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in results) {
      final sanitizedItem = _sanitizeTrack(item);
      if (sanitizedItem == null) continue;
      final id = sanitizedItem['id'] as String;
      if (seen.contains(id)) continue;
      seen.add(id);
      sanitized.add(sanitizedItem);
      if (sanitized.length >= limit) break;
    }
    if (sanitized.isNotEmpty) _cacheSet(key, sanitized);
    return sanitized;
  }

  Future<List<Map<String, dynamic>>> _performSearch(
      String query, String? params) async {
    final url =
        Uri.parse('https://music.youtube.com/youtubei/v1/search?alt=json');
    final body = <String, dynamic>{
      'context': {
        'client': {'clientName': 'WEB_REMIX', 'clientVersion': _clientVersion}
      },
      'query': query,
    };
    if (params != null) body['params'] = params;
    try {
      final resp = await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (compatible)',
                'x-youtube-client-name': 'WEB_REMIX',
                'x-youtube-client-version': _clientVersion,
              },
              body: jsonEncode(body))
          .timeout(_fetchTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
      final data = jsonDecode(resp.body);
      return _parseSearchResponse(data);
    } catch (e) {
      debugPrint('YtMusic search error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _parseSearchResponse(dynamic data) {
    if (data is! Map) return [];
    final candidates = <dynamic>[];
    void collect(dynamic node, int depth) {
      if (depth > 20 || candidates.length >= 5000) return;
      if (node == null) return;
      if (node is List) {
        for (final e in node) collect(e, depth + 1);
        return;
      }
      if (node is! Map) return;
      if (node.containsKey('musicResponsiveListItemRenderer') ||
          node.containsKey('musicTwoRowItemRenderer') ||
          node.containsKey('musicCardRenderer') ||
          node.containsKey('videoRenderer') ||
          node.containsKey('playlistPanelVideoRenderer') ||
          (node['richItemRenderer'] is Map &&
              (node['richItemRenderer'] as Map)['content'] != null)) {
        candidates.add(node);
      }
      for (final v in node.values) {
        if (v is List || v is Map) collect(v, depth + 1);
        if (candidates.length >= 5000) break;
      }
    }

    // Prioritize tabbedSearchResultsRenderer
    final contents = (data['contents'] as Map?);
    if (contents != null) {
      final tabbed = contents['tabbedSearchResultsRenderer'] as Map?;
      if (tabbed != null) {
        final tabs = tabbed['tabs'] as List?;
        if (tabs != null) {
          for (final t in tabs) {
            final content = (t as Map?)?['tabRenderer']?['content'];
            if (content != null) collect(content, 0);
          }
        }
      }
      final section = contents['sectionListRenderer'];
      if (section != null) collect(section, 0);
    }
    if (data['contents'] != null) collect(data['contents'], 0);
    if (candidates.isEmpty) collect(data, 0);

    final results = <Map<String, dynamic>>[];
    for (final node in candidates) {
      final Map<String, dynamic> possible;
      if (node is Map) {
        final m = node as Map<String, dynamic>;
        if (m['musicResponsiveListItemRenderer'] != null) {
          possible = Map<String, dynamic>.from(
              m['musicResponsiveListItemRenderer'] as Map);
        } else if (m['musicTwoRowItemRenderer'] != null) {
          possible = Map<String, dynamic>.from(
              m['musicTwoRowItemRenderer'] as Map);
        } else if (m['videoRenderer'] != null) {
          possible = Map<String, dynamic>.from(m['videoRenderer'] as Map);
        } else if (m['richItemRenderer'] != null) {
          final c = (m['richItemRenderer'] as Map)['content'];
          if (c is Map) {
            possible = Map<String, dynamic>.from(c);
          } else {
            continue;
          }
        } else {
          possible = Map<String, dynamic>.from(m);
        }
      } else {
        continue;
      }
      final parsed = _parseItemExtended(possible);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  Map<String, dynamic>? _parseItemExtended(Map<String, dynamic> c) {
    try {
      // title from flexColumns[0]
      String? title;
      final flexColumns = c['flexColumns'] as List?;
      if (flexColumns != null && flexColumns.isNotEmpty) {
        final fc0 = flexColumns[0] as Map?;
        final fcr = fc0?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        final text = fcr?['text'] as Map?;
        final runs = text?['runs'] as List?;
        if (runs != null && runs.isNotEmpty) {
          title = (runs[0] as Map)['text']?.toString();
        }
        if (title == null) {
          title = (text?['simpleText'] as String?) ??
              (fcr?['text']?['simpleText']?.toString());
        }
      }
      title ??= (c['title'] as Map?)?['runs']?[0]?['text']?.toString();
      title ??= (c['title'] as Map?)?['simpleText']?.toString();
      if (title == null || title.trim().isEmpty) return null;

      // artist from flexColumns[1] runs with browseId UC
      String artist = '';
      if (flexColumns != null && flexColumns.length > 1) {
        final fc1 = flexColumns[1] as Map?;
        final fcr = fc1?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        final text = fcr?['text'] as Map?;
        final runs = text?['runs'] as List?;
        if (runs != null) {
          final parts = <String>[];
          for (final r in runs) {
            final run = r as Map;
            final txt = run['text']?.toString().trim() ?? '';
            if (txt.isEmpty ||
                txt == '•' ||
                txt == ' · ' ||
                txt == ',' ||
                txt == ' & ') continue;
            final lower = txt.toLowerCase();
            if (['single', 'album', 'ep', 'playlist', 'video', 'song']
                .contains(lower)) continue;
            if (RegExp(r'^\d{4}$').hasMatch(txt)) continue;
            if (RegExp(r'^\d+(\.\d+)?[KMB]?\s*(views|plays|listeners)',
                    caseSensitive: false)
                .hasMatch(txt)) continue;
            if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(txt)) continue;
            final nav = run['navigationEndpoint'] as Map?;
            final browse = nav?['browseEndpoint'] as Map?;
            if (browse != null) {
              final bid = browse['browseId']?.toString() ?? '';
              if (bid.startsWith('UC')) parts.add(txt);
            } else if (nav == null) {
              if (txt.length > 1) parts.add(txt);
            }
          }
          if (parts.isNotEmpty) artist = parts.join(', ');
        }
      }
      if (artist.isEmpty) {
        final subtitle = c['subtitle'] as Map?;
        final runs = subtitle?['runs'] as List?;
        if (runs != null) {
          final parts = <String>[];
          for (final r in runs) {
            final run = r as Map;
            final txt = run['text']?.toString().trim() ?? '';
            if (txt.isEmpty || txt == '•' || txt == ',') continue;
            final lower = txt.toLowerCase();
            if (['single', 'album', 'ep', 'playlist', 'video', 'song']
                .contains(lower)) continue;
            if (RegExp(r'^\d{4}$').hasMatch(txt)) continue;
            if (RegExp(r'^\d+(\.\d+)?[KMB]?\s*(views|plays)',
                    caseSensitive: false)
                .hasMatch(txt)) continue;
            if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(txt)) continue;
            final nav = run['navigationEndpoint'] as Map?;
            final browse = nav?['browseEndpoint'] as Map?;
            if (browse != null) {
              final bid = browse['browseId']?.toString() ?? '';
              if (bid.startsWith('UC')) parts.add(txt);
            } else if (txt.length > 1) {
              parts.add(txt);
            }
          }
          if (parts.isNotEmpty) artist = parts.join(', ');
        }
      }

      // album from flexColumns runs with MPREb_
      String album = '';
      if (flexColumns != null && flexColumns.length > 1) {
        final fc1 = flexColumns[1] as Map?;
        final fcr = fc1?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        final runs = (fcr?['text'] as Map?)?['runs'] as List?;
        if (runs != null) {
          for (final r in runs) {
            final run = r as Map;
            final nav = run['navigationEndpoint'] as Map?;
            final browse = nav?['browseEndpoint'] as Map?;
            final bid = browse?['browseId']?.toString() ?? '';
            if (bid.startsWith('MPREb_')) {
              album = run['text']?.toString().trim() ?? '';
              break;
            }
          }
        }
      }

      // videoId
      String? videoId;
      videoId ??= (c['playlistItemData'] as Map?)?['videoId']?.toString();
      videoId ??= c['videoId']?.toString();
      if (videoId == null || videoId.isEmpty) {
        final overlay = c['overlay'] as Map?;
        final mitor = overlay?['musicItemThumbnailOverlayRenderer'] as Map?;
        final content = mitor?['content'] as Map?;
        final mpbr = content?['musicPlayButtonRenderer'] as Map?;
        final ep = mpbr?['playNavigationEndpoint'] as Map?;
        videoId = _extractVideoIdFromEndpoint(ep);
      }
      if (videoId == null || videoId.isEmpty) {
        videoId = _extractVideoIdFromEndpoint(
            c['navigationEndpoint'] as Map?);
      }
      if (videoId == null || videoId.isEmpty) {
        final thumb = c['thumbnail'] as Map?;
        final mtr = thumb?['musicThumbnailRenderer'] as Map?;
        final ep = mtr?['navigationEndpoint'] as Map?;
        videoId = _extractVideoIdFromEndpoint(ep);
      }
      if (videoId == null || videoId.isEmpty) return null;

      // duration
      String durationText = '';
      final lengthText = c['lengthText'] as Map?;
      if (lengthText != null) {
        durationText = lengthText['simpleText']?.toString() ?? '';
      }
      if (durationText.isEmpty) {
        final overlays = c['thumbnailOverlays'] as List?;
        if (overlays != null && overlays.isNotEmpty) {
          final tos =
              (overlays[0] as Map)['thumbnailOverlayTimeStatusRenderer'] as Map?;
          durationText =
              (tos?['text'] as Map?)?['simpleText']?.toString() ?? '';
        }
      }
      if (durationText.isEmpty) {
        final fixed = c['fixedColumns'] as List?;
        if (fixed != null) {
          for (final fc in fixed) {
            final fcr =
                (fc as Map)['musicResponsiveListItemFixedColumnRenderer']
                    as Map?;
            final txt = fcr?['text'] as Map?;
            final runs = txt?['runs'] as List?;
            final simple = txt?['simpleText']?.toString() ?? '';
            String? cand;
            if (runs != null && runs.isNotEmpty) {
              cand = (runs[0] as Map)['text']?.toString().trim();
            } else if (simple.isNotEmpty) {
              cand = simple.trim();
            }
            if (cand != null &&
                RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(cand)) {
              durationText = cand;
              break;
            }
          }
        }
      }
      final duration = _parseDurationText(durationText);

      // thumbnail
      String? thumbRaw;
      String? pickLastThumb(dynamic th) {
        if (th is List && th.isNotEmpty) {
          final last = th.last as Map;
          return last['url']?.toString();
        }
        return null;
      }

      thumbRaw ??= pickLastThumb(
          (c['thumbnail'] as Map?)?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails']);
      thumbRaw ??= pickLastThumb((c['thumbnail'] as Map?)?['thumbnails']);
      thumbRaw ??= pickLastThumb((c['thumbnail'] as Map?)?['thumbnail']
          ?['thumbnails']);
      String? thumb;
      if (thumbRaw != null) {
        thumb = _makeSquareThumb(thumbRaw);
      }

      return {
        'id': videoId,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration,
        'thumbnail': thumb,
        'explicit': _hasExplicitBadge(c),
      };
    } catch (e) {
      debugPrint('parseItemExtended error $e');
      return null;
    }
  }

  String? _extractVideoIdFromEndpoint(Map? ep) {
    if (ep == null) return null;
    final watch = ep['watchEndpoint'] as Map?;
    if (watch != null && watch['videoId'] != null) {
      return watch['videoId'].toString();
    }
    final cmd = ep['watchEndpoint'] as Map?;
    if (cmd != null) return cmd['videoId']?.toString();
    // browseEndpoint not video
    return null;
  }

  bool _hasExplicitBadge(Map<String, dynamic> c) {
    final badges = c['badges'] as List?;
    if (badges == null) return false;
    for (final b in badges) {
      final r = (b as Map)['musicInlineBadgeRenderer'] as Map?;
      if (r != null) {
        final icon = r['trackingParams']?.toString() ?? '';
        if (r['accessibilityData']?['label']?.toString().toLowerCase().contains('explicit') ==
            true) return true;
        if (icon.contains('explicit')) return true;
      }
      final mbr = (b as Map)['metadataBadgeRenderer'] as Map?;
      if (mbr?['label']?.toString().toLowerCase() == 'explicit') return true;
    }
    return false;
  }

  int _parseDurationText(String s) {
    final t = s.trim();
    if (t.isEmpty) return 0;
    final parts = t.split(':').map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length == 2) return parts[0] * 60 + parts[1];
    if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    return 0;
  }

  String _makeSquareThumb(String url) {
    try {
      final uri = Uri.parse(url);
      final w = uri.queryParameters['w'];
      final h = uri.queryParameters['h'];
      if (w != null && h != null) {
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['w'] = '512';
        newParams['h'] = '512';
        return uri.replace(queryParameters: newParams).toString();
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  Map<String, dynamic>? _sanitizeTrack(Map<String, dynamic> t) {
    final id = t['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final title = t['title']?.toString().trim() ?? 'Unknown title';
    final artist = t['artist']?.toString().trim() ?? '';
    final thumb = t['thumbnail']?.toString();
    final duration = t['duration'] is int ? t['duration'] as int : 0;
    return {
      'id': id,
      'name': title,
      'artists': artist,
      'album_name': t['album']?.toString() ?? '',
      'album_artist': '',
      'artist_id': '',
      'artist_url': '',
      'album_id': '',
      'album_url': '',
      'external_urls': 'https://music.youtube.com/watch?v=$id',
      'external_links': {'youtube': 'https://music.youtube.com/watch?v=$id'},
      'duration_ms': duration * 1000,
      'cover_url': thumb,
      'track_number': 0,
      'total_tracks': 0,
      'disc_number': 0,
      'total_discs': 0,
      'release_date': '',
      'album_type': '',
      'explicit': t['explicit'] == true,
      'provider_id': 'ytmusic-native',
      'item_type': 'track',
    };
  }

  List<Map<String, dynamic>>? _cacheGet(String key) {
    final data = _cache[key];
    final time = _cacheTime[key];
    if (data == null || time == null) return null;
    if (DateTime.now().difference(time) > _cacheTtl) {
      _cache.remove(key);
      _cacheTime.remove(key);
      return null;
    }
    return data['__list'] as List<Map<String, dynamic>>?;
  }

  void _cacheSet(String key, List<Map<String, dynamic>> value) {
    _cache[key] = {'__list': value};
    _cacheTime[key] = DateTime.now();
    if (_cache.length > 200) {
      final oldest = _cacheTime.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _cache.remove(oldest);
      _cacheTime.remove(oldest);
    }
  }

  // ---------- InnerTube download ----------
  Future<Map<String, dynamic>?> downloadToFile({
    required String trackId,
    String title = '',
    String artist = '',
    String quality = 'best',
    required String outputPath,
  }) async {
    try {
      final result =
          await _requestInnerTubeAudioDownload(trackId).timeout(
        const Duration(seconds: 25),
      );
      final url = result['url']?.toString();
      if (url == null || url.isEmpty) {
        return {'success': false, 'error': result['error']?.toString() ?? 'no url'};
      }
      final ext = result['extension']?.toString() ?? '.m4a';
      final downloaded = await _downloadAudioUrl(url, outputPath, ext);
      if (downloaded == null) {
        return {'success': false, 'error': 'file download failed'};
      }
      final cover = 'https://i.ytimg.com/vi/$trackId/hqdefault.jpg';
      return {
        'success': true,
        'file_path': downloaded,
        'actual_extension': ext,
        'cover_url': cover,
      };
    } catch (e) {
      debugPrint('YtMusic download error $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String?> getPlayablePath({
    required String trackId,
    String title = '',
    String artist = '',
  }) async {
    final tmp = await getTemporaryDirectory();
    final out =
        '${tmp.path}/melodi_play_${DateTime.now().millisecondsSinceEpoch}.bin';
    final result = await downloadToFile(
      trackId: trackId,
      title: title,
      artist: artist,
      outputPath: out,
    );
    if (result == null || result['success'] != true) return null;
    var path = (result['file_path'] ?? '').toString();
    if (path.isEmpty) return null;
    final actualExt = (result['actual_extension'] ?? '').toString();
    if (actualExt.isNotEmpty &&
        !path.toLowerCase().endsWith(actualExt.toLowerCase())) {
      try {
        final normalizedExt =
            actualExt.startsWith('.') ? actualExt : '.$actualExt';
        final renamed = path.replaceFirst(
            RegExp(r'\.[A-Za-z0-9]{1,5}$'), normalizedExt);
        if (renamed != path) {
          await File(path).rename(renamed);
          path = renamed;
        }
      } catch (_) {}
    }
    try {
      if (!await File(path).exists()) return null;
    } catch (_) {
      return null;
    }
    return path;
  }

  Future<Map<String, dynamic>> _requestInnerTubeAudioDownload(
      String videoId) async {
    String lastError = '';
    Map<String, dynamic>? pageInfo;
    try {
      pageInfo = await _getYouTubePageInfo(videoId);
    } catch (_) {
      pageInfo = {'visitorData': '', 'playerUrl': ''};
    }
    for (final client in _innerTubeClients) {
      final result = await _tryInnerTubeClient(videoId, client, pageInfo);
      if (result.containsKey('error')) {
        lastError = '${client['name']}: ${result['error']}';
        debugPrint('InnerTube ${client['name']} failed: ${result['error']}');
        continue;
      }
      return result;
    }
    throw Exception('innertube: all clients failed. Last: $lastError');
  }

  Future<Map<String, dynamic>> _tryInnerTubeClient(
    String videoId,
    Map<String, dynamic> clientConfig,
    Map<String, dynamic>? pageInfo,
  ) async {
    final visitorData = pageInfo?['visitorData']?.toString() ?? '';
    final bodyTemplate = clientConfig['body'] as Map<String, dynamic>;
    final body = jsonDecode(jsonEncode(bodyTemplate)) as Map<String, dynamic>;
    body['videoId'] = videoId;
    body['contentCheckOk'] = true;
    body['racyCheckOk'] = true;
    if (visitorData.isNotEmpty) {
      (body['context'] as Map)['client'] ??= {};
      (body['context']['client'] as Map)['visitorData'] = visitorData;
    }
    final key = clientConfig['key']?.toString() ?? _innerTubeApiKey;
    final url = Uri.parse(
        'https://www.youtube.com/youtubei/v1/player?key=$key&prettyPrint=false');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': clientConfig['ua']?.toString() ?? _innerTubeUserAgent,
      'Origin': 'https://www.youtube.com',
      'X-YouTube-Client-Name':
          clientConfig['clientHeaderName']?.toString() ?? '3',
      'X-YouTube-Client-Version':
          (body['context']['client']['clientVersion']?.toString() ??
              _innerTubeClientVersion),
    };
    if (visitorData.isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = visitorData;
    }
    try {
      final resp = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return {'error': 'HTTP ${resp.statusCode}'};
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final playStatus =
          (data['playabilityStatus'] as Map?)?['status']?.toString() ?? '?';
      if (playStatus != 'OK') {
        final reason = (data['playabilityStatus'] as Map?)?['reason']
                ?.toString() ??
            playStatus;
        return {'error': reason};
      }
      final sd = data['streamingData'] as Map?;
      if (sd == null) return {'error': 'no streamingData'};
      final formats = <Map<String, dynamic>>[];
      final fmts = sd['formats'] as List?;
      final adaptive = sd['adaptiveFormats'] as List?;
      if (fmts != null) {
        for (final f in fmts) formats.add(Map<String, dynamic>.from(f as Map));
      }
      if (adaptive != null) {
        for (final f in adaptive) {
          formats.add(Map<String, dynamic>.from(f as Map));
        }
      }
      final best = _chooseYouTubeFormat(formats);
      if (best == null) {
        return {'error': 'no usable audio URL (fmts=${formats.length})'};
      }
      final bestUrl = best['url']?.toString() ??
          best['signatureCipher']?.toString() ??
          '';
      String? finalUrl = bestUrl;
      if (finalUrl == null || finalUrl.isEmpty) {
        final cipher = best['signatureCipher']?.toString() ??
            best['cipher']?.toString() ??
            '';
        if (cipher.isNotEmpty) {
          finalUrl = _decodeCipher(cipher);
        }
      }
      if (finalUrl == null || finalUrl.isEmpty || !finalUrl.startsWith('http')) {
        return {'error': 'audio URL solving failed (itag=${best['itag']})'};
      }
      final ext = _outputExtensionFromYouTubeFormat(best);
      return {
        'url': finalUrl,
        'extension': ext,
        'itag': best['itag'],
        'mimeType': best['mimeType']?.toString() ?? '',
        'bitrate': best['averageBitrate'] ?? best['bitrate'] ?? 0,
        'clientName': clientConfig['name'],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  String? _decodeCipher(String cipher) {
    try {
      final params = Uri.splitQueryString(cipher);
      var url = params['url'];
      final s = params['s'];
      if (url == null) return null;
      url = Uri.decodeComponent(url);
      // Signature decipher not implemented — most recent clients deliver direct url,
      // cipher fallback will fail; return null to try next client.
      if (s != null) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _chooseYouTubeFormat(
      List<Map<String, dynamic>> formats) {
    Map<String, dynamic>? best;
    int bestScore = -1;
    bool hasUsableUrl(Map<String, dynamic> f) {
      final url = f['url']?.toString() ?? '';
      if (url.isNotEmpty && url.startsWith('http')) return true;
      final cipher = f['signatureCipher']?.toString() ??
          f['cipher']?.toString() ??
          '';
      return cipher.isNotEmpty;
    }

    int scoreFormat(Map<String, dynamic> f) {
      final mime = f['mimeType']?.toString().toLowerCase() ?? '';
      int s = 0;
      if (mime.contains('opus')) s += 10;
      if (mime.contains('mp4') || mime.contains('m4a')) s += 20;
      final bitrate = (f['averageBitrate'] as num?)?.toInt() ??
          (f['bitrate'] as num?)?.toInt() ??
          0;
      s += (bitrate / 10000).round();
      return s;
    }

    for (final itag in _audioItagPreference) {
      for (final fmt in formats) {
        if ((fmt['itag'] as num?)?.toInt() != itag) continue;
        if (!hasUsableUrl(fmt)) continue;
        final score = scoreFormat(fmt);
        if (score > bestScore) {
          best = fmt;
          bestScore = score;
        }
      }
      if (best != null) return best;
    }
    for (final fmt in formats) {
      if (!hasUsableUrl(fmt)) continue;
      final score = scoreFormat(fmt);
      if (score > bestScore) {
        best = fmt;
        bestScore = score;
      }
    }
    return best;
  }

  String _outputExtensionFromYouTubeFormat(Map<String, dynamic> fmt) {
    final mime = fmt['mimeType']?.toString().toLowerCase() ?? '';
    if (mime.contains('opus') || mime.contains('webm')) return '.opus';
    if (mime.contains('mp4') || mime.contains('m4a')) return '.m4a';
    if (mime.contains('mp3')) return '.mp3';
    final itag = (fmt['itag'] as num?)?.toInt();
    if (itag == 140 || itag == 141 || itag == 139) return '.m4a';
    if (itag == 251 || itag == 250 || itag == 249) return '.opus';
    return '.m4a';
  }

  Future<Map<String, dynamic>?> _getYouTubePageInfo(String videoId) async {
    try {
      final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
      final resp = await http
          .get(url, headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
          })
          .timeout(const Duration(seconds: 10));
      final body = resp.body;
      String visitorData = '';
      String playerUrl = '';
      final vdMatch = RegExp(r'"visitorData"\s*:\s*"([^"]+)"').firstMatch(body);
      if (vdMatch != null) visitorData = vdMatch.group(1) ?? '';
      final puMatch = RegExp(r'"PLAYER_JS_URL"\s*:\s*"([^"]+)"').firstMatch(body);
      if (puMatch != null) playerUrl = puMatch.group(1) ?? '';
      return {'visitorData': visitorData, 'playerUrl': playerUrl};
    } catch (_) {
      return {'visitorData': '', 'playerUrl': ''};
    }
  }

  Future<String?> _downloadAudioUrl(
      String url, String outputPath, String ext) async {
    var path = outputPath.trim();
    if (path.isEmpty) {
      final tmp = await getTemporaryDirectory();
      path =
          '${tmp.path}/melodi_yt_${DateTime.now().millisecondsSinceEpoch}$ext';
    }
    if (!path.toLowerCase().endsWith(ext.toLowerCase())) {
      if (RegExp(r'\.[A-Za-z0-9]{1,5}$').hasMatch(path)) {
        path = path.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), ext);
      } else {
        path = '$path$ext';
      }
    }
    final file = File(path);
    try {
      await file.parent.create(recursive: true);
    } catch (_) {}
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 25));
      request.headers.set('User-Agent',
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1');
      final resp = await request.close().timeout(const Duration(seconds: 25));
      if (resp.statusCode != 200 && resp.statusCode != 206) return null;
      final sink = file.openWrite(mode: FileMode.write);
      try {
        await for (final data in resp.timeout(const Duration(seconds: 60))) {
          sink.add(data);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final len = await file.length();
      if (len < 1000) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      return path;
    } catch (e) {
      debugPrint('downloadAudioUrl error $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
