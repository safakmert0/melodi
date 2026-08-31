import 'dart:typed_data';

enum MusicSourceType { youtube, jiosaavn, deezer, navidrome, hifi, appleMusic, soundcloud }

extension MusicSourceTypeCapabilities on MusicSourceType {
  bool get supportsFullTrack =>
      this == MusicSourceType.youtube ||
      this == MusicSourceType.jiosaavn ||
      this == MusicSourceType.navidrome ||
      this == MusicSourceType.hifi ||
      this == MusicSourceType.appleMusic ||
      this == MusicSourceType.soundcloud;

  bool get isPreviewCatalogue => this == MusicSourceType.deezer;
}

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
  final String? extensionId;
  final String? extensionName;

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
    this.extensionId,
    this.extensionName,
  });

  String get sourceLabel {
    if (extensionName != null && extensionName!.isNotEmpty) return extensionName!;
    switch (source) {
      case MusicSourceType.youtube:
        return 'YouTube';
      case MusicSourceType.jiosaavn:
        return 'JioSaavn';
      case MusicSourceType.deezer:
        return 'Deezer';
      case MusicSourceType.navidrome:
        return 'Navidrome';
      case MusicSourceType.hifi:
        return 'Hi-Fi';
      case MusicSourceType.appleMusic:
        return 'Apple Music';
      case MusicSourceType.soundcloud:
        return 'SoundCloud';
    }
  }

  OnlineTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? thumbnailUrl,
    Uint8List? thumbnailBytes,
    MusicSourceType? source,
    String? streamUrl,
    String? extensionId,
    String? extensionName,
  }) {
    return OnlineTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      source: source ?? this.source,
      streamUrl: streamUrl ?? this.streamUrl,
      extensionId: extensionId ?? this.extensionId,
      extensionName: extensionName ?? this.extensionName,
    );
  }
}

abstract class MusicSource {
  MusicSourceType get type;
  String get name;
  Future<List<OnlineTrack>> search(String query, {int limit = 20});
  Future<String?> getStreamUrl(OnlineTrack track);
  Future<void> dispose();
}