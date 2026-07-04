import 'dart:typed_data';

enum MusicSourceType { youtube, jiosaavn, deezer, lastfm }

class OnlineTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String? thumbnailUrl;
  final Uint8List? thumbnailBytes;
  final MusicSourceType source;
  final String? streamUrl;

  const OnlineTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration = Duration.zero,
    this.thumbnailUrl,
    this.thumbnailBytes,
    required this.source,
    this.streamUrl,
  });

  String get sourceLabel {
    switch (source) {
      case MusicSourceType.youtube:
        return 'YouTube';
      case MusicSourceType.jiosaavn:
        return 'JioSaavn';
      case MusicSourceType.deezer:
        return 'Deezer';
      case MusicSourceType.lastfm:
        return 'Last.fm';
    }
  }
}

abstract class MusicSource {
  MusicSourceType get type;
  String get name;
  Future<List<OnlineTrack>> search(String query, {int limit = 20});
  Future<String?> getStreamUrl(OnlineTrack track);
  Future<void> dispose();
}
