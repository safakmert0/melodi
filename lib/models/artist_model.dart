import 'dart:typed_data';

class ArtistModel {
  final String id;
  final String name;
  final Uint8List? image;
  final int albumCount;
  final int songCount;
  final List<String> albumIds;
  final List<String> songIds;

  ArtistModel({
    required this.id,
    required this.name,
    this.image,
    required this.albumCount,
    required this.songCount,
    required this.albumIds,
    required this.songIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'albumCount': albumCount,
      'songCount': songCount,
      'albumIds': albumIds.join(','),
      'songIds': songIds.join(','),
    };
  }

  factory ArtistModel.fromMap(Map<String, dynamic> map) {
    return ArtistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      albumCount: map['albumCount'] as int,
      songCount: map['songCount'] as int,
      albumIds:
          (map['albumIds'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      songIds:
          (map['songIds'] as String).split(',').where((s) => s.isNotEmpty).toList(),
    );
  }
}
