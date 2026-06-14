import 'dart:typed_data';

class AlbumModel {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final Uint8List? artwork;
  final int songCount;
  final Duration totalDuration;
  final int year;
  final List<String> songIds;

  AlbumModel({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.artwork,
    required this.songCount,
    required this.totalDuration,
    required this.year,
    required this.songIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'artistId': artistId,
      'songCount': songCount,
      'totalDurationMs': totalDuration.inMilliseconds,
      'year': year,
      'songIds': songIds.join(','),
    };
  }

  factory AlbumModel.fromMap(Map<String, dynamic> map) {
    return AlbumModel(
      id: map['id'] as String,
      name: map['name'] as String,
      artist: map['artist'] as String,
      artistId: map['artistId'] as String?,
      songCount: map['songCount'] as int,
      totalDuration: Duration(milliseconds: map['totalDurationMs'] as int),
      year: map['year'] as int,
      songIds: (map['songIds'] as String).split(',').where((s) => s.isNotEmpty).toList(),
    );
  }
}
