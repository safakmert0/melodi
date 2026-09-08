import 'dart:async';
import 'package:flutter/foundation.dart';
import 'download_manager.dart';
import 'navidrome_service.dart';

class RemotePlaylist {
  final String id;
  final String name;
  final String? description;
  final String sourceType;
  final String? artworkUrl;
  final int trackCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isOwner;
  final bool collaborative;

  const RemotePlaylist({
    required this.id,
    required this.name,
    this.description,
    required this.sourceType,
    this.artworkUrl,
    this.trackCount = 0,
    this.createdAt,
    this.updatedAt,
    this.isOwner = false,
    this.collaborative = false,
  });

  factory RemotePlaylist.fromJson(Map<String, dynamic> json, String sourceType) {
    return RemotePlaylist(
      id: json['id']?.toString() ?? json['playlistId']?.toString() ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? 'Bilinmeyen',
      description: json['description'] as String?,
      sourceType: sourceType,
      artworkUrl: json['artworkUrl'] as String? ?? json['thumbnailUrl'] as String?,
      trackCount: json['trackCount'] as int? ?? json['songCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      isOwner: json['isOwner'] as bool? ?? true,
      collaborative: json['collaborative'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sourceType': sourceType,
    'artworkUrl': artworkUrl,
    'trackCount': trackCount,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isOwner': isOwner,
    'collaborative': collaborative,
  };
}

class RemotePlaylistTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? artworkUrl;
  final String sourceType;
  final String sourceId;

  const RemotePlaylistTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.artworkUrl,
    required this.sourceType,
    required this.sourceId,
  });
}

class RemotePlaylistService {
  RemotePlaylistService._();
  static final RemotePlaylistService _instance = RemotePlaylistService._();
  factory RemotePlaylistService() => _instance;
  static RemotePlaylistService get instance => _instance;

  final NavidromeService _navidrome = NavidromeService.instance;

  Future<List<RemotePlaylist>> getAllPlaylists() async {
    final playlists = <RemotePlaylist>[];

    try {
      if (await _navidrome.isConfigured()) {
        final navidromePlaylists = await _navidrome.getPlaylists();
        playlists.addAll(navidromePlaylists
            .map((p) => RemotePlaylist.fromJson(p.toJson(), 'navidrome'))
            .toList());
      }
    } catch (e) {
      debugPrint('Navidrome playlists error: $e');
    }


    return playlists;
  }

  Future<List<RemotePlaylistTrack>> getPlaylistTracks(String playlistId, String sourceType) async {
    switch (sourceType) {
      case 'navidrome':
        return _getNavidromePlaylistTracks(playlistId);
      default:
        return [];
    }
  }

  Future<List<RemotePlaylistTrack>> _getNavidromePlaylistTracks(String playlistId) async {
    try {
      final songs = await _navidrome.getPlaylistTracks(playlistId);
      return songs
          .map((s) => RemotePlaylistTrack(
                id: s.id,
                title: s.title,
                artist: s.artist,
                album: s.album,
                durationMs: s.duration.inMilliseconds,
                artworkUrl: s.thumbnailUrl,
                sourceType: 'navidrome',
                sourceId: s.id,
              ))
          .toList();
    } catch (e) {
      debugPrint('Navidrome playlist tracks error: $e');
      return [];
    }
  }


  Future<bool> createPlaylist({
    required String name,
    required String sourceType,
    String? description,
    List<String>? trackIds,
  }) async {
    switch (sourceType) {
      case 'navidrome':
        return _createNavidromePlaylist(name, description, trackIds);
      default:
        return false;
    }
  }

  Future<bool> _createNavidromePlaylist(
    String name,
    String? description,
    List<String>? trackIds,
  ) async {
    try {
      return await _navidrome.createPlaylist(name, trackIds ?? []);
    } catch (e) {
      debugPrint('Create Navidrome playlist error: $e');
      return false;
    }
  }


  Future<bool> updatePlaylist({
    required String playlistId,
    required String sourceType,
    String? name,
    String? description,
    List<String>? addTrackIds,
    List<String>? removeTrackIds,
  }) async {
    switch (sourceType) {
      case 'navidrome':
        return _updateNavidromePlaylist(playlistId, name, description, addTrackIds, removeTrackIds);
      default:
        return false;
    }
  }

  Future<bool> _updateNavidromePlaylist(
    String playlistId,
    String? name,
    String? description,
    List<String>? addTrackIds,
    List<String>? removeTrackIds,
  ) async {
    try {
      if (addTrackIds != null && addTrackIds.isNotEmpty) {
        await _navidrome.addToPlaylist(playlistId, addTrackIds);
      }
      if (removeTrackIds != null && removeTrackIds.isNotEmpty) {
        await _navidrome.removeFromPlaylist(playlistId, removeTrackIds);
      }
      return true;
    } catch (e) {
      debugPrint('Update Navidrome playlist error: $e');
      return false;
    }
  }


  Future<bool> deletePlaylist(String playlistId, String sourceType) async {
    switch (sourceType) {
      case 'navidrome':
        return _deleteNavidromePlaylist(playlistId);
      default:
        return false;
    }
  }

  Future<bool> _deleteNavidromePlaylist(String playlistId) async {
    try {
      return await _navidrome.deletePlaylist(playlistId);
    } catch (e) {
      debugPrint('Delete Navidrome playlist error: $e');
      return false;
    }
  }


  Future<bool> downloadPlaylistToLocal(
    String playlistId,
    String sourceType, {
    void Function(int, int)? onProgress,
  }) async {
    final tracks = await getPlaylistTracks(playlistId, sourceType);
    if (tracks.isEmpty) return false;

    final downloadManager = DownloadManager();
    var completed = 0;

    for (final track in tracks) {
      downloadManager.addTask(
        spotifyTrackId: '$sourceType:${track.id}',
        title: track.title,
        artist: track.artist,
        album: track.album,
        imageUrl: track.artworkUrl,
        sourceVideoId: track.sourceId,
        expectedDurationMs: track.durationMs ?? 0,
      );

      completed++;
      onProgress?.call(completed, tracks.length);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return true;
  }

  Future<String?> sharePlaylist(String playlistId, String sourceType) async {
    switch (sourceType) {
      case 'navidrome':
        return _shareNavidromePlaylist(playlistId);
      default:
        return null;
    }
  }

  Future<String?> _shareNavidromePlaylist(String playlistId) async {
    try {
      final navidrome = NavidromeService.instance;
      final baseUrl = await navidrome.getBaseUrl();
      return '$baseUrl/playlist/$playlistId';
    } catch (_) {
      return null;
    }
  }


  Future<void> dispose() async {}
}
