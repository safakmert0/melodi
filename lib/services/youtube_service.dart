import 'dart:io';
import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class YouTubeVideo {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;
  final String? audioUrl;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnailUrl,
    this.audioUrl,
  });
}

class YouTubeService {
  YoutubeExplode? _yt;
  static const Duration _timeout = Duration(seconds: 30);

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

  Future<String?> getAudioUrl(String videoId) async {
    try {
      final manifest = await _client.videos.streams
          .getManifest(videoId, ytClients: [YoutubeApiClient.ios])
          .timeout(_timeout);
      final audio = manifest.audioOnly;
      if (audio.isEmpty) return null;
      return _bestAudio(audio).url.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> _downloadTo(String videoId, String title, Directory dir,
      {String ext = '.m4a'}) async {
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final filePath = p.join(dir.path, '${sanitized}_$videoId$ext');
      final file = File(filePath);
      if (await file.exists()) return filePath;

      final manifest = await _client.videos.streams
          .getManifest(videoId, ytClients: [YoutubeApiClient.ios])
          .timeout(_timeout);
      final audio = manifest.audioOnly;
      if (audio.isEmpty) return null;
      final best = _bestAudio(audio);

      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(best.url);
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.close();
      } finally {
        httpClient.close();
      }
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> playAudio(String videoId, String title) async {
    try {
      final url = await getAudioUrl(videoId);
      if (url != null) return url;
      final dir = await getTemporaryDirectory();
      return await _downloadTo(videoId, title, dir);
    } catch (e) {
      return null;
    }
  }

  Future<String?> downloadAudio(String videoId, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return await _downloadTo(videoId, title, dir);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _yt?.close();
  }
}
