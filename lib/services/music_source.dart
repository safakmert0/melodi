import 'dart:typed_data';

enum MusicSourceType { youtube }

extension MusicSourceTypeCapabilities on MusicSourceType {
  bool get supportsFullTrack => this == MusicSourceType.youtube;

  bool get isPreviewCatalogue => false;
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
  /// YTM arama türü: 'song' (müzik/art track), 'video' (klip) ya da ''.
  /// Müzik sürümleri akışta/gömülü oynatıcıda neredeyse hiç engellenmez.
  final String itemType;

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
    this.itemType = '',
  });

  String get sourceLabel {
    if (extensionName != null && extensionName!.isNotEmpty) return extensionName!;
    return 'YouTube';
  }

  /// Klip sürümü mü? Klipler gömülü oynatıcıda ve doğrudan akışta
  /// daha sık engellenir (embed kapalı / giriş koruması).
  bool get isVideo => itemType.trim().toLowerCase() == 'video';

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
    String? itemType,
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
      itemType: itemType ?? this.itemType,
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