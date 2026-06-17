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
  static const Duration _timeout = Duration(seconds: 20);

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

  Future<String?> _downloadTo(String videoId, String title, Directory dir,
      {String ext = '.m4a'}) async {
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final filePath = p.join(dir.path, '${sanitized}_$videoId$ext');

      final manifest = await _client.videos.streams
          .getManifest(videoId)
          .timeout(_timeout);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;
      final sorted = List<AudioOnlyStreamInfo>.from(audioStreams)
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      final bestAudio = sorted.first;

      final stream = _client.videos.streams.get(bestAudio);
      final file = File(filePath);
      final sink = file.openWrite();
      await sink.addStream(stream.timeout(_timeout));
      await sink.close();
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getAudioUrl(String videoId) async {
    try {
      final manifest = await _client.videos.streams
          .getManifest(videoId)
          .timeout(_timeout);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;
      final sorted = List<AudioOnlyStreamInfo>.from(audioStreams)
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      return sorted.first.url.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> playAudio(String videoId, String title) async {
    try {
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
