import 'package:audio_service/audio_service.dart';

import 'queue.dart';
import '../../music_source.dart';

class ListQueue extends Queue {
  final List<OnlineTrack> tracks;
  final String title;
  int _currentIndex;

  ListQueue({
    required this.tracks,
    required this.title,
    int startIndex = 0,
  }) : _currentIndex = startIndex.clamp(0, tracks.length - 1);

  @override
  Future<QueueStatus> getInitialStatus() async {
    return QueueStatus(
      title: title,
      items: tracks.map((t) => OnlineTrackToMediaItem(t).toMediaItem()).toList(),
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
  int get length => tracks.length;
  OnlineTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < tracks.length ? tracks[_currentIndex] : null;
}