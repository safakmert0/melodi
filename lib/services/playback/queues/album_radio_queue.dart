import 'package:audio_service/audio_service.dart';

import 'queue.dart';
import '../../music_source.dart';

class AlbumRadioQueue extends Queue {
  final String _albumBrowseId;
  final String _title;
  String? _continuation;
  List<OnlineTrack> _cachedTracks = [];

  AlbumRadioQueue({
    required String albumBrowseId,
    String title = 'Album Radio',
  })  : _albumBrowseId = albumBrowseId,
        _title = title;

  @override
  Future<QueueStatus> getInitialStatus() async {
    return QueueStatus(
      title: _title,
      items: _cachedTracks.map((t) => OnlineTrackToMediaItem(t).toMediaItem()).toList(),
      mediaItemIndex: 0,
    );
  }

  @override
  bool get hasNextPage => _continuation != null;

  @override
  Future<List<MediaItem>> nextPage() async {
    return [];
  }

  @override
  Future<void> dispose() async {
    _cachedTracks.clear();
    _continuation = null;
  }
}

class LocalAlbumRadioQueue extends Queue {
  final List<OnlineTrack> localTracks;
  final String _title;
  int _currentIndex = 0;

  LocalAlbumRadioQueue({
    required this.localTracks,
    String title = 'Local Album Radio',
  }) : _title = title;

  @override
  Future<QueueStatus> getInitialStatus() async {
    return QueueStatus(
      title: _title,
      items: localTracks.map((t) => OnlineTrackToMediaItem(t).toMediaItem()).toList(),
      mediaItemIndex: _currentIndex,
    );
  }

  @override
  bool get hasNextPage => false;

  @override
  Future<List<MediaItem>> nextPage() async => [];

  @override
  Future<void> dispose() async {}

  int get currentIndex => _currentIndex;
  int get length => localTracks.length;
}