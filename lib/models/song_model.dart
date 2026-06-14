import 'dart:typed_data';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final Duration duration;
  final String filePath;
  final Uint8List? albumArt;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final int? bitrate;
  final int? sampleRate;
  final String? mimeType;
  final int fileSize;
  final DateTime dateAdded;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayed;

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
  }) : dateAdded = dateAdded ?? DateTime.now();

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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
