import 'package:audio_service/audio_service.dart';
import 'dart:convert';

import '../../music_source.dart';
import '../../../models/song_model.dart';

abstract class Queue {
  Future<QueueStatus> getInitialStatus();
  bool get hasNextPage;
  Future<List<MediaItem>> nextPage();
  Future<void> dispose();
}

class QueueStatus {
  final String title;
  final List<MediaItem> items;
  final int mediaItemIndex;

  QueueStatus({
    required this.title,
    required this.items,
    required this.mediaItemIndex,
  });
}

extension OnlineTrackToMediaItem on OnlineTrack {
  MediaItem toMediaItem({
    String? artworkUrl,
    String? album,
    Duration? duration,
    Map<String, dynamic>? extras,
  }) {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : (thumbnailUrl != null ? Uri.tryParse(thumbnailUrl!) : null),
      extras: {
        'source': source.name,
        'itemType': itemType,
        'extensionId': extensionId,
        'extensionName': extensionName,
        ...?extras,
      },
    );
  }
}

extension SongModelToMediaItem on SongModel {
  MediaItem toMediaItem({
    String? artworkUrl,
    Map<String, dynamic>? extras,
  }) {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : (albumArt != null && albumArt!.isNotEmpty ? Uri.parse('data:image/png;base64,${base64Encode(albumArt!)}') : null),
      extras: {
        'source': 'local',
        'isLocal': true,
        'path': filePath,
        ...?extras,
      },
    );
  }
}