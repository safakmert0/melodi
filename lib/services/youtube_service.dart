import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
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
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  Future<List<YouTubeVideo>> search(String query) async {
    try {
      final results = await _yt.search(query);
      final videos = <YouTubeVideo>[];
      await for (final video in results) {
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

  Future<String?> getAudioUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;
      final bestAudio = audioStreams
          .where((s) => s.bitrate > 0)
          .reduce((a, b) => a.bitrate > b.bitrate ? a : b);
      return bestAudio.url.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> downloadAudio(String videoId, String title) async {
    try {
      final audioUrl = await getAudioUrl(videoId);
      if (audioUrl == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final filePath = p.join(dir.path, '${sanitized}.mp4');

      await _dio.download(audioUrl, filePath);
      return filePath;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}
