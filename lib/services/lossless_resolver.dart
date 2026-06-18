import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class LosslessTrackDetail {
  final String isrc;
  final String title;
  final String artist;
  final String album;
  final String? upc;
  final int durationMs;

  const LosslessTrackDetail({
    required this.isrc,
    required this.title,
    required this.artist,
    required this.album,
    this.upc,
    required this.durationMs,
  });
}

class DeezerTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? isrc;
  final String? coverUrl;
  final Duration duration;
  final bool lossless;

  const DeezerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.isrc,
    this.coverUrl,
    required this.duration,
    this.lossless = false,
  });
}

class QobuzTrack {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String? isrc;
  final int durationMs;
  final int maximumBitDepth;
  final int maximumSamplingRate;

  const QobuzTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.isrc,
    required this.durationMs,
    this.maximumBitDepth = 16,
    this.maximumSamplingRate = 44100,
  });
}

class LosslessResolver {
  LosslessResolver._();

  static const String _deezerApiBase = 'https://api.deezer.com/2.0';
  static const String _qobuzApiBase = 'https://www.qobuz.com/api.json/0.2';
  static const String _spotifyWebApi = 'https://api.spotify.com/v1';
  static const String _squidWtfApi =
      'https://api.services.squid.wtf';

  static const Map<String, String> _qobuzHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'X-App-Id': '100000001',
    'Origin': 'https://play.qobuz.com',
    'Referer': 'https://play.qobuz.com/',
  };

  static Future<LosslessTrackDetail?> getSpotifyTrackDetail(
      String trackId, String accessToken) async {
    try {
      final url = '$_spotifyWebApi/tracks/$trackId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Spotify track detail failed: ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final externalIds = body['external_ids'] as Map<String, dynamic>?;
      final isrc = externalIds?['isrc'] as String?;

      if (isrc == null || isrc.isEmpty) {
        debugPrint('No ISRC for track $trackId');
        return null;
      }

      final albumObj = body['album'] as Map<String, dynamic>?;
      final album = albumObj?['name'] as String? ?? 'Unknown Album';
      final upc = albumObj?['external_ids']?['upc'] as String?;

      final artists = (body['artists'] as List<dynamic>?)
              ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ') ??
          'Unknown Artist';

      return LosslessTrackDetail(
        isrc: isrc,
        title: body['name'] as String? ?? 'Unknown',
        artist: artists,
        album: album,
        upc: upc,
        durationMs: body['duration_ms'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('getSpotifyTrackDetail failed: $e');
      return null;
    }
  }

  static Future<DeezerTrack?> searchDeezerByIsrc(String isrc) async {
    try {
      final url = '$_deezerApiBase/track/isrc:$isrc';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.containsKey('error')) return null;

      final id = body['id']?.toString();
      if (id == null) return null;

      final artistData = body['artist'] as Map<String, dynamic>?;
      final albumData = body['album'] as Map<String, dynamic>?;

      return DeezerTrack(
        id: id,
        title: body['title'] as String? ?? 'Unknown',
        artist: artistData?['name'] as String? ?? 'Unknown Artist',
        album: albumData?['title'] as String? ?? 'Unknown Album',
        isrc: isrc,
        coverUrl: body['album']?['cover_big'] as String?,
        duration: Duration(seconds: body['duration'] as int? ?? 0),
        lossless: true,
      );
    } catch (e) {
      debugPrint('searchDeezerByIsrc failed: $e');
      return null;
    }
  }

  static Future<QobuzTrack?> searchQobuzByIsrc(String isrc) async {
    try {
      final appId = await _getQobuzAppId();
      if (appId == null) return null;

      final searchUrl =
          '$_qobuzApiBase/catalog/search?query=$isrc&limit=10&offset=0&app_id=$appId';
      final searchResponse = await http.get(
        Uri.parse(searchUrl),
        headers: _qobuzHeaders,
      );

      if (searchResponse.statusCode != 200) return null;

      final searchBody = jsonDecode(searchResponse.body) as Map<String, dynamic>;
      final tracks = searchBody['tracks']?['items'] as List<dynamic>?;
      if (tracks == null || tracks.isEmpty) return null;

      for (final item in tracks) {
        final track = item as Map<String, dynamic>;
        final trackIsrc = track['isrc'] as String?;
        if (trackIsrc?.toUpperCase() == isrc.toUpperCase()) {
          final id = track['id'] as int?;
          if (id == null) continue;

          final performers = track['performers'] as List<dynamic>?;
          final artist = performers
                  ?.map((p) => (p as Map<String, dynamic>)['name'] as String?)
                  .where((n) => n != null)
                  .join(', ') ??
              'Unknown Artist';

          final albumObj = track['album'] as Map<String, dynamic>?;

          return QobuzTrack(
            id: id,
            title: track['title'] as String? ?? 'Unknown',
            artist: artist,
            album: albumObj?['title'] as String? ?? 'Unknown Album',
            isrc: isrc,
            durationMs: track['duration'] as int? ?? 0,
            maximumBitDepth: track['maximum_bit_depth'] as int? ?? 16,
            maximumSamplingRate: track['maximum_sampling_rate'] as int? ?? 44100,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('searchQobuzByIsrc failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getBestSource(String isrc) async {
    final deezer = await searchDeezerByIsrc(isrc);
    if (deezer != null) {
      final url = await getDeezerDownloadUrl(int.tryParse(deezer.id) ?? 0);
      if (url != null) {
        return {
          'source': 'deezer',
          'url': url,
          'trackId': deezer.id,
          'coverUrl': deezer.coverUrl,
        };
      }
    }

    final qobuz = await searchQobuzByIsrc(isrc);
    if (qobuz != null) {
      final url = await getQobuzDownloadUrl(qobuz.id);
      if (url != null) {
        return {
          'source': 'qobuz',
          'url': url,
          'trackId': qobuz.id.toString(),
        };
      }
    }

    final squidUrl = await getSquidWtfUrl(isrc);
    if (squidUrl != null) {
      return {
        'source': 'squid',
        'url': squidUrl,
      };
    }

    return {};
  }

  static Future<String?> getDeezerDownloadUrl(int trackId) async {
    try {
      final url = '$_deezerApiBase/track/$trackId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final previewUrl = body['preview'] as String?;

      if (previewUrl != null && previewUrl.isNotEmpty) {
        return previewUrl.replaceAll('preview.mp3', 'flac.mp3');
      }

      final md5Image = body['album']?['cover_md5'] as String?;
      if (md5Image != null) {
        final trackHash = _deezerTrackHash(trackId, md5Image);
        if (trackHash != null) {
          return 'https://e-cdns-proxy-${trackHash['cdn']}.deezer.com/mobile/3/${trackHash['media']}';
        }
      }

      return null;
    } catch (e) {
      debugPrint('getDeezerDownloadUrl failed: $e');
      return null;
    }
  }

  static Map<String, String>? _deezerTrackHash(int trackId, String md5Image) {
    try {
      final step1 = utf8.encode('$md5Image\u00a4$trackId\u00a4${md5Image[0]}${md5Image[1]}${md5Image[2]}');
      final step2 = step1.map((b) => b ^ 0xa4).toList();
      final step3 = base64Encode(step2);
      final step4 = step3.replaceFirst(RegExp(r'=+$'), '');
      final step5 = step4.replaceAll('/', '_').replaceAll('+', '-');

      final cdn = '${md5Image[0]}${md5Image[1]}${md5Image[2]}';
      return {
        'media': step5,
        'cdn': cdn,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getQobuzDownloadUrl(int trackId) async {
    try {
      final appId = await _getQobuzAppId();
      if (appId == null) return null;

      final url = '$_qobuzApiBase/track/getFileUrl'
          '?track_id=$trackId&format_id=27&app_id=$appId';
      final response = await http.get(
        Uri.parse(url),
        headers: _qobuzHeaders,
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['url'] as String?;
    } catch (e) {
      debugPrint('getQobuzDownloadUrl failed: $e');
      return null;
    }
  }

  static Future<String?> _getQobuzAppId() async {
    try {
      final db = DatabaseService.instance;
      final cached = await db.getSetting('qobuz_app_id');
      if (cached != null && cached.isNotEmpty) return cached;

      final response = await http.get(
        Uri.parse('https://play.qobuz.com'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      final body = response.body;
      final regex = RegExp(r'"app_id"\s*:\s*"(\d+)"');
      final match = regex.firstMatch(body);
      final appId = match?.group(1);

      if (appId != null) {
        await db.setSetting('qobuz_app_id', appId);
      }

      return appId;
    } catch (e) {
      debugPrint('_getQobuzAppId failed: $e');
      return '100000001';
    }
  }

  static Future<String?> getSquidWtfUrl(String isrc) async {
    try {
      final url = '$_squidWtfApi/search?isrc=$isrc';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['url'] as String?;
    } catch (e) {
      debugPrint('getSquidWtfUrl failed: $e');
      return null;
    }
  }

  static Future<String> downloadFLAC(
    String url,
    String outputPath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);
      request.headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
      });

      final httpClient = http.Client();
      final streamedResponse = await httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        throw HttpException(
            'Download failed with status ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      var bytesDownloaded = 0;

      final file = File(outputPath);
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;

        if (contentLength > 0 && onProgress != null) {
          onProgress(bytesDownloaded / contentLength);
        }
      }

      await sink.flush();
      await sink.close();
      httpClient.close();

      return outputPath;
    } catch (e) {
      debugPrint('downloadFLAC failed: $e');
      rethrow;
    }
  }

  static Future<List<int>> fetchCoverArt(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes.toList();
      }
      return [];
    } catch (e) {
      debugPrint('fetchCoverArt failed: $e');
      return [];
    }
  }

  static Future<String?> getHighResCoverUrl(
      String spotifyTrackId, String accessToken) async {
    try {
      final db = DatabaseService.instance;
      final cached = await db.getHighResArtUrl(spotifyTrackId);
      if (cached != null && cached.isNotEmpty) return cached;

      final url = '$_spotifyWebApi/tracks/$spotifyTrackId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final albumObj = body['album'] as Map<String, dynamic>?;
      final images = albumObj?['images'] as List<dynamic>?;

      if (images != null && images.isNotEmpty) {
        String? bestUrl;
        var bestSize = 0;

        for (final img in images) {
          final imgMap = img as Map<String, dynamic>;
          final imgUrl = imgMap['url'] as String?;
          final width = imgMap['width'] as int? ?? 0;
          final height = imgMap['height'] as int? ?? 0;
          final size = width * height;

          if (imgUrl != null && size > bestSize) {
            bestUrl = imgUrl;
            bestSize = size;
          }
        }

        if (bestUrl != null) {
          await db.saveHighResArtUrl(spotifyTrackId, bestUrl);
          return bestUrl;
        }
      }

      return null;
    } catch (e) {
      debugPrint('getHighResCoverUrl failed: $e');
      return null;
    }
  }
}
