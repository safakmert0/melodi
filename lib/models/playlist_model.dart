import 'dart:typed_data';

class PlaylistModel {
  final String id;
  final String name;
  final String? description;
  final Uint8List? artwork;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSmartPlaylist;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    this.artwork,
    required this.songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSmartPlaylist = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get songCount => songIds.length;

  PlaylistModel copyWith({
    String? id,
    String? name,
    String? description,
    Uint8List? artwork,
    List<String>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSmartPlaylist,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      artwork: artwork ?? this.artwork,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSmartPlaylist: isSmartPlaylist ?? this.isSmartPlaylist,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'songIds': songIds.join(','),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSmartPlaylist': isSmartPlaylist ? 1 : 0,
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      songIds:
          (map['songIds'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isSmartPlaylist: (map['isSmartPlaylist'] as int?) == 1,
    );
  }
}
