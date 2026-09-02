import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';

/// Platform where the track is available
enum TrackPlatform {
  local('local'),
  spotify('spotify'),
  youtube('youtube'),
  online('online'),
  navidrome('navidrome'),
  jiosaavn('jiosaavn'),
  qqmusic('qqmusic'),
  kugou('kugou'),
  netease('netease');

  final String value;
  const TrackPlatform(this.value);
  @override
  String toString() => value;
}

/// Track availability status
enum TrackAvailability {
  available('available'),
  streaming('streaming'),
  downloaded('downloaded'),
  offline('offline'),
  error('error');

  final String value;
  const TrackAvailability(this.value);
  @override
  String toString() => value;
}

/// Quality level for downloads
enum DownloadQuality {
  low('low'),
  medium('medium'),
  high('high'),
  lossless('lossless');

  final String value;
  const DownloadQuality(this.value);
  @override
  String toString() => value;
}

/// Streamability status
enum StreamStatus {
  canStream('can_stream'),
  cannotStream('cannot_stream'),
  requiresPurchase('requires_purchase'),
  regionLocked('region_locked');

  final String value;
  const StreamStatus(this.value);
  @override
  String toString() => value;
}

/// Collection type
enum CollectionType {
  album('album'),
  playlist('playlist'),
  artist('artist'),
  song('song'),
  podcast('podcast'),
  mix('mix'),
  radio('radio');

  final String value;
  const CollectionType(this.value);
  @override
  String toString() => value;
}

class SongModel {
  /// Unique track identifier (can be Spotify ID, YouTube ID, Navidrome path, or local file path)
  final String id;

  /// Track title
  final String title;

  /// Artist name
  final String artist;

  /// Album name
  final String album;

  /// Album artist (if different from artist)
  final String? albumArtist;

  /// Duration of the track
  final Duration duration;

  /// File path for local tracks, or stream URL for online tracks
  final String filePath;

  /// Album art as bytes
  final Uint8List? albumArt;

  /// Genre
  final String? genre;

  /// Track number on album
  final int? trackNumber;

  /// Disc number
  final int? discNumber;

  /// Release year
  final int? year;

  /// Bitrate in kbps
  final int? bitrate;

  /// Sample rate in Hz
  final int? sampleRate;

  /// MIME type
  final String? mimeType;

  /// File size in bytes
  final int fileSize;

  /// When the track was added to library
  final DateTime dateAdded;

  /// Whether track is marked as favorite
  final bool isFavorite;

  /// Play count
  final int playCount;

  /// Last played timestamp
  final DateTime? lastPlayed;

  /// Lyrics (plain text or synced)
  final String? lyrics;

  /// Playback speed multiplier
  final double playbackSpeed;

  /// Volume boost level
  final double volumeBoost;

  /// Platform where this track is available
  final TrackPlatform platform;

  /// Availability status
  final TrackAvailability availability;

  /// Whether track can be streamed
  final StreamStatus streamStatus;

  /// Download quality setting
  final DownloadQuality downloadQuality;

  /// Whether track is currently downloading
  final bool isDownloading;

  /// Whether track is locally available and downloaded
  final bool isDownloaded;

  /// Collection type this track belongs to
  final CollectionType? collectionType;

  /// Spotify track ID (if applicable)
  final String? spotifyId;

  /// Apple Music track ID (if applicable)
  final String? appleMusicId;

  /// ISRC code
  final String? isrc;

  /// Composer
  final String? composer;

  /// Copyright text
  final String? copyright;

  /// Explicit content flag
  final bool? explicit;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    required this.duration,
    required this.filePath,
    this.albumArt,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.bitrate,
    this.sampleRate,
    this.mimeType,
    required this.fileSize,
    DateTime? dateAdded,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayed,
    this.lyrics,
    this.playbackSpeed = 1.0,
    this.volumeBoost = 1.0,
    this.platform = TrackPlatform.local,
    this.availability = TrackAvailability.available,
    this.streamStatus = StreamStatus.canStream,
    this.downloadQuality = DownloadQuality.high,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.collectionType,
    this.spotifyId,
    this.appleMusicId,
    this.isrc,
    this.composer,
    this.copyright,
    this.explicit,
  }) : dateAdded = dateAdded ?? DateTime.now();

  /// Creates a SongModel from a map (for database/json serialization)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'durationMs': duration.inMilliseconds,
      'filePath': filePath,
      'albumArt': albumArt != null ? base64Encode(albumArt!) : null,
      'genre': genre,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'year': year,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'dateAdded': dateAdded.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'playCount': playCount,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'lyrics': lyrics,
      'playbackSpeed': playbackSpeed,
      'volumeBoost': volumeBoost,
      'platform': platform.value,
      'availability': availability.value,
      'streamStatus': streamStatus.value,
      'downloadQuality': downloadQuality.value,
      'isDownloading': isDownloading ? 1 : 0,
      'isDownloaded': isDownloaded ? 1 : 0,
      'collectionType': collectionType?.value,
      'spotifyId': spotifyId,
      'appleMusicId': appleMusicId,
      'isrc': isrc,
      'composer': composer,
      'copyright': copyright,
      'explicit': explicit?.toString() ?? '0',
    };
  }

  /// Creates a SongModel from a map (for database/json deserialization)
  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      albumArtist: map['albumArtist'] as String?,
      duration: Duration(milliseconds: map['durationMs'] as int),
      filePath: map['filePath'] as String,
      albumArt: map['albumArt'] != null
          ? base64Decode(map['albumArt'] as String)
          : null,
      genre: map['genre'] as String?,
      trackNumber: map['trackNumber'] as int?,
      discNumber: map['discNumber'] as int?,
      year: map['year'] as int?,
      bitrate: map['bitrate'] as int?,
      sampleRate: map['sampleRate'] as int?,
      mimeType: map['mimeType'] as String?,
      fileSize: map['fileSize'] as int,
      dateAdded: map['dateAdded'] != null
          ? DateTime.parse(map['dateAdded'] as String)
          : null,
      isFavorite: (map['isFavorite'] as int?) == 1,
      playCount: map['playCount'] as int? ?? 0,
      lastPlayed: map['lastPlayed'] != null
          ? DateTime.parse(map['lastPlayed'] as String)
          : null,
      lyrics: map['lyrics'] as String?,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      volumeBoost: (map['volumeBoost'] as num?)?.toDouble() ?? 1.0,
      platform: TrackPlatform.values.firstWhere(
        (e) => e.value == (map['platform'] as String? ?? 'local'),
        orElse: () => TrackPlatform.local,
      ),
      availability: TrackAvailability.values.firstWhere(
        (e) => e.value == (map['availability'] as String? ?? 'available'),
        orElse: () => TrackAvailability.available,
      ),
      streamStatus: StreamStatus.values.firstWhere(
        (e) => e.value == (map['streamStatus'] as String? ?? 'can_stream'),
        orElse: () => StreamStatus.canStream,
      ),
      downloadQuality: DownloadQuality.values.firstWhere(
        (e) => e.value == (map['downloadQuality'] as String? ?? 'high'),
        orElse: () => DownloadQuality.high,
      ),
      isDownloading: (map['isDownloading'] as int?) == 1,
      isDownloaded: (map['isDownloaded'] as int?) == 1,
      collectionType: map['collectionType'] != null
          ? CollectionType.values.firstWhere(
              (e) => e.value == (map['collectionType'] as String),
              orElse: () => CollectionType.song,
            )
          : null,
      spotifyId: map['spotifyId'] as String?,
      appleMusicId: map['appleMusicId'] as String?,
      isrc: map['isrc'] as String?,
      composer: map['composer'] as String?,
      copyright: map['copyright'] as String?,
      explicit: map['explicit'] != null ? bool.parse(map['explicit'] as String) : null,
    );
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    Duration? duration,
    String? filePath,
    Uint8List? albumArt,
    String? genre,
    int? trackNumber,
    int? discNumber,
    int? year,
    int? bitrate,
    int? sampleRate,
    String? mimeType,
    int? fileSize,
    DateTime? dateAdded,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayed,
    String? lyrics,
    double? playbackSpeed,
    double? volumeBoost,
    TrackPlatform? platform,
    TrackAvailability? availability,
    StreamStatus? streamStatus,
    DownloadQuality? downloadQuality,
    bool? isDownloading,
    bool? isDownloaded,
    CollectionType? collectionType,
    String? spotifyId,
    String? appleMusicId,
    String? isrc,
    String? composer,
    String? copyright,
    bool? explicit,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      albumArt: albumArt ?? this.albumArt,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      lyrics: lyrics ?? this.lyrics,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volumeBoost: volumeBoost ?? this.volumeBoost,
      platform: platform ?? this.platform,
      availability: availability ?? this.availability,
      streamStatus: streamStatus ?? this.streamStatus,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      isDownloading: isDownloading ?? this.isDownloading,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      collectionType: collectionType ?? this.collectionType,
      spotifyId: spotifyId ?? this.spotifyId,
      appleMusicId: appleMusicId ?? this.appleMusicId,
      isrc: isrc ?? this.isrc,
      composer: composer ?? this.composer,
      copyright: copyright ?? this.copyright,
      explicit: explicit ?? this.explicit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  String toJson() => jsonEncode(toMap());

  factory SongModel.fromJson(String json) =>
      SongModel.fromMap(jsonDecode(json) as Map<String, dynamic>);

  static List<SongModel> listFromJson(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => SongModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<SongModel> songs) {
    return jsonEncode(songs.map((s) => s.toMap()).toList());
  }

  /// Check if this track can be played locally
  bool get canPlayLocal {
    if (filePath.startsWith('youtube://') || filePath.startsWith('http')) return false;
    if (!isDownloaded && platform == TrackPlatform.local) return false;
    return File(filePath).existsSync();
  }

  /// Check if this track can be streamed
  bool get canStream {
    if (streamStatus == StreamStatus.canStream) return true;
    if (availability == TrackAvailability.streaming) return true;
    return false;
  }

  /// Get display platform name
  String get platformDisplayName {
    switch (platform) {
      case TrackPlatform.spotify:
        return 'Spotify';
      case TrackPlatform.youtube:
        return 'YouTube';
      case TrackPlatform.online:
        return 'Online';
      case TrackPlatform.navidrome:
        return 'Navidrome';
      case TrackPlatform.jiosaavn:
        return 'JioSaavn';
      case TrackPlatform.qqmusic:
        return 'QQ Music';
      case TrackPlatform.kugou:
        return 'Kugou';
      case TrackPlatform.netease:
        return 'NetEase';
      case TrackPlatform.local:
      default:
        return 'Local';
    }
  }

  /// Get availability display name
  String get availabilityDisplayName {
    switch (availability) {
      case TrackAvailability.available:
        return 'Müşteri';
      case TrackAvailability.streaming:
        return 'Abonelik';
      case TrackAvailability.downloaded:
        return 'İndirilmiş';
      case TrackAvailability.offline:
        return 'Çevrimdışı';
      case TrackAvailability.error:
        return 'Hata';
    }
  }

  /// Get stream status display name
  String get streamStatusDisplayName {
    switch (streamStatus) {
      case StreamStatus.canStream:
        return 'Dinleyebilir';
      case StreamStatus.cannotStream:
        return 'Dinlenemez';
      case StreamStatus.requiresPurchase:
        return 'Satın Alması Gerekli';
      case StreamStatus.regionLocked:
        return 'Coğrafi Kısıtlama';
    }
  }

  /// Get download quality display name
  String get downloadQualityDisplayName {
    switch (downloadQuality) {
      case DownloadQuality.low:
        return 'Düşük';
      case DownloadQuality.medium:
        return 'Orta';
      case DownloadQuality.high:
        return 'Yüksek';
      case DownloadQuality.lossless:
        return 'Kaybedersiz';
    }
  }
}

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'durationMs': duration.inMilliseconds,
      'filePath': filePath,
      'genre': genre,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'year': year,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'dateAdded': dateAdded.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'playCount': playCount,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'lyrics': lyrics,
      'playbackSpeed': playbackSpeed,
      'volumeBoost': volumeBoost,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      albumArtist: map['albumArtist'] as String?,
      duration: Duration(milliseconds: map['durationMs'] as int),
      filePath: map['filePath'] as String,
      genre: map['genre'] as String?,
      trackNumber: map['trackNumber'] as int?,
      discNumber: map['discNumber'] as int?,
      year: map['year'] as int?,
      bitrate: map['bitrate'] as int?,
      sampleRate: map['sampleRate'] as int?,
      mimeType: map['mimeType'] as String?,
      fileSize: map['fileSize'] as int,
      dateAdded: map['dateAdded'] != null
          ? DateTime.parse(map['dateAdded'] as String)
          : null,
      isFavorite: (map['isFavorite'] as int?) == 1,
      playCount: map['playCount'] as int? ?? 0,
      lastPlayed: map['lastPlayed'] != null
          ? DateTime.parse(map['lastPlayed'] as String)
          : null,
      lyrics: map['lyrics'] as String?,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      volumeBoost: (map['volumeBoost'] as num?)?.toDouble() ?? 1.0,
    );
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    Duration? duration,
    String? filePath,
    Uint8List? albumArt,
    String? genre,
    int? trackNumber,
    int? discNumber,
    int? year,
    int? bitrate,
    int? sampleRate,
    String? mimeType,
    int? fileSize,
    DateTime? dateAdded,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayed,
    String? lyrics,
    double? playbackSpeed,
    double? volumeBoost,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      albumArt: albumArt ?? this.albumArt,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      lyrics: lyrics ?? this.lyrics,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volumeBoost: volumeBoost ?? this.volumeBoost,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  String toJson() => jsonEncode(toMap());

  factory SongModel.fromJson(String json) =>
      SongModel.fromMap(jsonDecode(json) as Map<String, dynamic>);

  static List<SongModel> listFromJson(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => SongModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<SongModel> songs) {
    return jsonEncode(songs.map((s) => s.toMap()).toList());
  }
}
