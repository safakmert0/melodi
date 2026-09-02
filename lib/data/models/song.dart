import 'package:freezed_annotation/freezed_annotation.dart';

part 'song.freezed.dart';
part 'song.g.dart';

@freezed
abstract class Song with _$Song {
  const factory Song({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? albumArtist,
    String? composer,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    int? durationMs,
    String? isrc,
    String? lyrics,
    String? coverUrl,
    String? localPath,
    @Default(false) bool isLocal,
    @Default(false) bool isDownloaded,
    String? source,
    String? quality,
    Map<String, String>? extras,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Song;

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}

@freezed
abstract class Album with _$Album {
  const factory Album({
    required String id,
    required String title,
    required String artist,
    String? artistId,
    String? coverUrl,
    int? year,
    String? genre,
    int? trackCount,
    int? durationMs,
    @Default(false) bool isLocal,
    @Default(false) bool isDownloaded,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}

@freezed
abstract class Artist with _$Artist {
  const factory Artist({
    required String id,
    required String name,
    String? coverUrl,
    String? bio,
    int? albumCount,
    int? trackCount,
    @Default(false) bool isLocal,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Artist;

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
}

@freezed
abstract class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String name,
    String? description,
    String? coverUrl,
    @Default([]) List<String> trackIds,
    @Default(false) bool isLocal,
    @Default(false) bool isSmart,
    String? source,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Playlist;

  factory Playlist.fromJson(Map<String, dynamic> json) => _$PlaylistFromJson(json);
}

@freezed
abstract class StreamUrl with _$StreamUrl {
  const factory StreamUrl({
    required String url,
    required String mimeType,
    int? bitrate,
    required String quality,
    required String provider,
    required String trackId,
    Map<String, String>? headers,
    int? expiresAt,
    String? checksum,
    int? size,
    @Default(false) bool isLocal,
  }) = _StreamUrl;

  factory StreamUrl.fromJson(Map<String, dynamic> json) => _$StreamUrlFromJson(json);
}

@freezed
abstract class DownloadJob with _$DownloadJob {
  const factory DownloadJob({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? coverUrl,
    required String url,
    required String quality,
    @Default(0) int progress,
    @Default(0) int bytesDownloaded,
    @Default(0) int totalBytes,
    @Default(0) int speed,
    @Default('pending') String state,
    String? error,
    String? outputPath,
    String? isrc,
    int? durationMs,
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) = _DownloadJob;

  factory DownloadJob.fromJson(Map<String, dynamic> json) => _$DownloadJobFromJson(json);
}

@freezed
abstract class ExtensionManifest with _$ExtensionManifest {
  const factory ExtensionManifest({
    required String id,
    required String name,
    required String description,
    required String version,
    required String author,
    required ExtensionKind kind,
    required ExtensionProtocol protocol,
    required String baseUrl,
    required String homepage,
    required String minAppVersion,
    required List<String> capabilities,
    required List<String> permissions,
    required String healthPath,
    required String healthMethod,
  }) = _ExtensionManifest;

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) => _$ExtensionManifestFromJson(json);
}

@freezed
abstract class InstalledExtension with _$InstalledExtension {
  const factory InstalledExtension({
    required ExtensionManifest manifest,
    required bool enabled,
    required DateTime installedAt,
    String? health,
  }) = _InstalledExtension;

  factory InstalledExtension.fromJson(Map<String, dynamic> json) => _$InstalledExtensionFromJson(json);
}

enum ExtensionKind {
  @JsonValue('backend')
  backend,
  @JsonValue('hifi')
  hifi,
  @JsonValue('metadata')
  metadata,
  @JsonValue('lyrics')
  lyrics,
  @JsonValue('stream')
  stream,
  @JsonValue('download')
  download,
}

enum ExtensionProtocol {
  @JsonValue('yt-dlp-backend')
  ytDlpBackend,
  @JsonValue('piped')
  piped,
  @JsonValue('subsonic')
  subsonic,
  @JsonValue('navidrome')
  navidrome,
  @JsonValue('hifi-lossless')
  hifiLossless,
  @JsonValue('custom')
  custom,
}