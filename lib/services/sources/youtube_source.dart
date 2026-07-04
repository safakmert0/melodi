import '../music_source.dart';
import '../youtube_service.dart';

class YouTubeMusicSource implements MusicSource {
  final YouTubeService _service = YouTubeService();

  @override
  MusicSourceType get type => MusicSourceType.youtube;

  @override
  String get name => 'YouTube';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    try {
      final videos = await _service.search(query);
      return videos.take(limit).map((v) => OnlineTrack(
        id: v.id,
        title: v.title,
        artist: v.author,
        duration: v.duration,
        thumbnailUrl: v.thumbnailUrl,
        source: MusicSourceType.youtube,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    return await _service.getAudioUrl(track.id);
  }

  @override
  Future<void> dispose() async {
    _service.dispose();
  }
}
