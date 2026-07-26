import '../music_source.dart';
import '../navidrome_service.dart';

class NavidromeSource implements MusicSource {
  final NavidromeService _service = NavidromeService.instance;

  @override
  MusicSourceType get type => MusicSourceType.navidrome;

  @override
  String get name => 'Navidrome';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    if (!await _service.isConfigured()) return const [];
    return _service.search(query, limit: limit);
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    if (!await _service.isConfigured()) return null;
    return track.streamUrl ?? _service.streamUrl(track.id);
  }

  @override
  Future<void> dispose() async {}
}
