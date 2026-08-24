import 'dart:async';
import '../backend_api_service.dart';
import '../music_source.dart';
import '../robust_piped_service.dart';

class YouTubeMusicSource implements MusicSource {
  final BackendApiService _backend = BackendApiService.instance;
  final RobustPipedService _piped = RobustPipedService.instance;

  @override
  MusicSourceType get type => MusicSourceType.youtube;

  @override
  String get name => 'YouTube Music';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final results = <OnlineTrack>[];

    // 1. Backend (yt-dlp) - en yüksek kalite, metadata dahil
    try {
      final endpoint = await _backend.resolveEndpoint();
      if (endpoint != null) {
        final videos = await _backend.search(query, limit: limit);
        results.addAll(videos
            .map((v) => OnlineTrack(
                  id: v.id,
                  title: v.title,
                  artist: v.author,
                  duration: Duration(seconds: v.duration),
                  thumbnailUrl: v.thumbnail,
                  source: MusicSourceType.youtube,
                ))
            .toList());
        if (results.length >= limit) return results.take(limit).toList();
      }
    } catch (_) {}

    // 2. Robust Piped - otomatik failover, proxy ile IP gizleme
    try {
      final pipedTracks = await _piped.search(query, limit: limit - results.length);
      results.addAll(pipedTracks);
      if (results.length >= limit) return results.take(limit).toList();
    } catch (_) {}

    return results.take(limit).toList();
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    // 1. Backend proxy stream
    try {
      final url = await _backend.streamUrl(track.id);
      if (url != null) return url;
    } catch (_) {}

    // 2. Robust Piped - otomatik instance failover, proxy ile
    try {
      return await _piped.getStreamUrl(track.id);
    } catch (_) {}

    return null;
  }

  @override
  Future<void> dispose() async {}
}