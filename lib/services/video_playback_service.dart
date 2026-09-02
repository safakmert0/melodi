import 'dart:async';
import 'robust_piped_service.dart';

class VideoPlaybackService {
  VideoPlaybackService._();
  static final VideoPlaybackService _instance = VideoPlaybackService._();
  factory VideoPlaybackService() => _instance;
  static VideoPlaybackService get instance => _instance;

  final RobustPipedService _piped = RobustPipedService.instance;

  Future<VideoInfo?> getVideoInfo(String videoId) async {
    return await _piped.getVideoInfo(videoId);
  }

  Future<List<VideoFormat>> getVideoFormats(String videoId) async {
    final info = await getVideoInfo(videoId);
    if (info == null) return [];

    return info.formats
        .where((f) => f.hasVideo)
        .toList()
      ..sort((a, b) => b.height.compareTo(a.height));
  }

  Future<VideoFormat?> getBestVideoFormat(
    String videoId, {
    int maxHeight = 1080,
    bool preferMP4 = true,
  }) async {
    final formats = await getVideoFormats(videoId);
    if (formats.isEmpty) return null;

    var filtered = formats.where((f) => f.height <= maxHeight).toList();
    if (filtered.isEmpty) filtered = formats;

    if (preferMP4) {
      final mp4 = filtered.where((f) => f.mimeType.contains('mp4')).toList();
      if (mp4.isNotEmpty) filtered = mp4;
    }

    filtered.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return filtered.first;
  }

  Future<String?> getVideoStreamUrl(
    String videoId, {
    int maxHeight = 1080,
  }) async {
    final format = await getBestVideoFormat(videoId, maxHeight: maxHeight);
    return format?.url;
  }

  Future<String?> getAudioOnlyStreamUrl(String videoId) async {
    final info = await getVideoInfo(videoId);
    if (info == null) return null;

    final audioFormats = info.formats
        .where((f) => f.hasAudio && !f.hasVideo)
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    return audioFormats.isNotEmpty ? audioFormats.first.url : null;
  }

  Future<VideoInfo?> searchVideo(String query, {int limit = 10}) async {
    final tracks = await _piped.search(query, limit: limit);
    if (tracks.isEmpty) return null;
    return await getVideoInfo(tracks.first.id);
  }
}