import 'dart:typed_data';

enum MusicSourceType { youtube, hifi, soundcloud, slskd }

extension MusicSourceTypeCapabilities on MusicSourceType {
  bool get supportsFullTrack => true;

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
    switch (source) {
      case MusicSourceType.youtube:
        return 'YouTube';
      case MusicSourceType.hifi:
        return 'Hi-Fi';
      case MusicSourceType.soundcloud:
        return 'SoundCloud';
      case MusicSourceType.slskd:
        return 'Soulseek';
    }
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'thumbnailUrl': thumbnailUrl,
        'source': source.name,
        'streamUrl': streamUrl,
        'extensionId': extensionId,
        'extensionName': extensionName,
        'itemType': itemType,
      };

  factory OnlineTrack.fromJson(Map<String, dynamic> json) => OnlineTrack(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String?,
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        thumbnailUrl: json['thumbnailUrl'] as String?,
        source: MusicSourceType.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => MusicSourceType.youtube,
        ),
        streamUrl: json['streamUrl'] as String?,
        extensionId: json['extensionId'] as String?,
        extensionName: json['extensionName'] as String?,
        itemType: json['itemType'] as String? ?? '',
      );
}

abstract class MusicSource {
  MusicSourceType get type;
  String get name;
  Future<List<OnlineTrack>> search(String query, {int limit = 20});
  Future<String?> getStreamUrl(OnlineTrack track);
  Future<void> dispose();
}