import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;


class YouTubeVideo {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;
  final Uint8List? thumbnailBytes;
  final String? audioUrl;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnailUrl,
    this.thumbnailBytes,
    this.audioUrl,
  });
}

class YouTubeService {
  YoutubeExplode? _yt;
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _downloadTimeout = Duration(seconds: 120);
  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  static final List<YoutubeApiClient> _clients = [
    YoutubeApiClient.ios,
    YoutubeApiClient.android,
    YoutubeApiClient.safari,
  ];

  YoutubeExplode get _client {
    _yt ??= YoutubeExplode();
    return _yt!;
  }

  Future<List<YouTubeVideo>> search(String query) async {
    try {
      final results = await _client.search
          .search(query)
          .timeout(_timeout);
      final videos = <YouTubeVideo>[];
      for (final video in results) {
        if (video.duration != null && video.duration!.inSeconds > 0) {
          videos.add(YouTubeVideo(
            id: video.id.value,
            title: video.title,
            author: video.author,
            duration: video.duration!,
            thumbnailUrl: video.thumbnails.standardResUrl,
          ));
        }
        if (videos.length >= 20) break;
      }
      return videos;
    } catch (e) {
      debugPrint('YouTube search error: $e');
      return [];
    }
  }

  AudioOnlyStreamInfo _bestAudio(Iterable<AudioOnlyStreamInfo> streams) {
    final m4a = streams.where((s) => s.container == StreamContainer.mp4);
    final candidates = m4a.isNotEmpty ? m4a : streams;
    return candidates.reduce(
      (a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b,
    );
  }

  Future<String?> _tryGetManifest(String videoId) async {
    for (final client in _clients) {
      try {
        final manifest = await _client.videos.streams
            .getManifest(videoId, ytClients: [client])
            .timeout(_timeout);
        final audio = manifest.audioOnly;
        if (audio.isNotEmpty) {
          final url = _bestAudio(audio).url.toString();
          debugPrint('YouTube: got audio URL via $client');
          return url;
        }
        debugPrint('YouTube: $client returned no audio streams');
      } catch (e) {
        debugPrint('YouTube: $client failed: $e');
      }
    }
    return null;
  }

  Future<String?> getAudioUrl(String videoId) async {
    return await _tryGetManifest(videoId);
  }

  Future<String?> _downloadAudio(String videoId, String title, Directory dir,
      {String ext = '.m4a'}) async {
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      String safeTitle = sanitized.isEmpty ? videoId : sanitized;
      final filePath = p.join(dir.path, '${safeTitle}_$videoId$ext');
      final file = File(filePath);
      if (await file.exists()) return filePath;

      final url = await _tryGetManifest(videoId);
      if (url == null) return null;

      debugPrint('YouTube: downloading audio from $url');

      final httpClient = HttpClient()
        ..userAgent = _userAgent
        ..connectionTimeout = _downloadTimeout;
      try {
        final request = await httpClient.getUrl(Uri.parse(url));
        request.headers.set('User-Agent', _userAgent);
        final response = await request.close();
        if (response.statusCode != 200) {
          debugPrint('YouTube download HTTP ${response.statusCode}');
          return null;
        }
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.close();
        final len = await file.length();
        debugPrint('YouTube: downloaded ${len} bytes');
        if (len < 1000) {
          await file.delete();
          debugPrint('YouTube: file too small, deleted');
          return null;
        }
      } finally {
        httpClient.close();
      }
      return filePath;
    } catch (e) {
      debugPrint('YouTube download error: $e');
      return null;
    }
  }

  Future<String?> playAudio(String videoId, String title) async {
    try {
      final dir = await getTemporaryDirectory();
      return await _downloadAudio(videoId, title, dir);
    } catch (e) {
      debugPrint('YouTube playAudio error: $e');
      return null;
    }
  }

  Future<String?> downloadAudio(String videoId, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return await _downloadAudio(videoId, title, dir);
    } catch (e) {
      debugPrint('YouTube downloadAudio error: $e');
      return null;
    }
  }

  void dispose() {
    _yt?.close();
  }
}
