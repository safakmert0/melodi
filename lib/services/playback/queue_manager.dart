import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../music_source.dart';
import 'queues/queue.dart';
import 'queues/list_queue.dart';
import 'queues/youtube_music_queue.dart';
import 'queues/album_radio_queue.dart';

/// QueueManager — InnerTune tarzı kuyruk yöneticisi.
/// Farklı kaynaklardan (YouTube Music, playlist, album, radio, local)
/// gelen kuyrukları yönetir ve audio_service'a MediaItem listesi sağlar.
class QueueManager {
  Queue? _currentQueue;
  List<MediaItem> _mediaItems = [];
  int _currentIndex = 0;
  String _currentQueueTitle = '';

  Queue? get currentQueue => _currentQueue;
  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);
  int get currentIndex => _currentIndex;
  String get currentQueueTitle => _currentQueueTitle;
  bool get hasQueue => _currentQueue != null;
  int get queueLength => _mediaItems.length;

  /// Yeni bir kuyruk yükle
  Future<QueueStatus> loadQueue(Queue queue, {int startIndex = 0}) async {
    await _currentQueue?.dispose();
    _currentQueue = queue;
    final status = await queue.getInitialStatus();
    _mediaItems = status.items;
    _currentIndex = status.mediaItemIndex.clamp(0, _mediaItems.length - 1);
    _currentQueueTitle = status.title;
    return status;
  }

  /// YouTube Music radyo kuyruğu (şarkı bazlı)
  Future<QueueStatus> loadYouTubeRadio(OnlineTrack seedTrack) async {
    final queue = YouTubeMusicQueue.radio(seedTrack);
    return loadQueue(queue);
  }

  /// YouTube Music albüm kuyruğu
  Future<QueueStatus> loadYouTubeAlbum(String albumBrowseId) async {
    final queue = YouTubeMusicQueue.album(albumBrowseId);
    return loadQueue(queue);
  }

  /// YouTube Music playlist kuyruğu
  Future<QueueStatus> loadYouTubePlaylist(String playlistId) async {
    final queue = YouTubeMusicQueue.playlist(playlistId);
    return loadQueue(queue);
  }

  /// Statik liste kuyruğu (playlist, album, artist tracks)
  Future<QueueStatus> loadList({
    required List<OnlineTrack> tracks,
    required String title,
    int startIndex = 0,
  }) async {
    final queue = ListQueue(tracks: tracks, title: title, startIndex: startIndex);
    return loadQueue(queue, startIndex: startIndex);
  }

  /// Yerel albüm radyosu
  Future<QueueStatus> loadLocalAlbumRadio(List<OnlineTrack> localTracks) async {
    final queue = LocalAlbumRadioQueue(localTracks: localTracks);
    return loadQueue(queue);
  }

  /// Sonraki sayfa yükle (infinite scroll / radio continuation)
  Future<List<MediaItem>> loadNextPage() async {
    if (_currentQueue == null || !_currentQueue!.hasNextPage) return [];
    final newItems = await _currentQueue!.nextPage();
    _mediaItems.addAll(newItems);
    return newItems;
  }

  /// Mevcut parçayı al
  MediaItem? get currentMediaItem =>
      _currentIndex >= 0 && _currentIndex < _mediaItems.length
          ? _mediaItems[_currentIndex]
          : null;

  /// İndeksi güncelle
  void setCurrentIndex(int index) {
    _currentIndex = index.clamp(0, _mediaItems.length - 1);
  }

  /// Sonraki parça
  MediaItem? next() {
    if (_currentIndex + 1 < _mediaItems.length) {
      _currentIndex++;
      return _mediaItems[_currentIndex];
    }
    return null;
  }

  /// Önceki parça
  MediaItem? previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      return _mediaItems[_currentIndex];
    }
    return null;
  }

  void clear() {
    _currentQueue?.dispose();
    _currentQueue = null;
    _mediaItems.clear();
    _currentIndex = 0;
    _currentQueueTitle = '';
  }

  @override
  String toString() =>
      'QueueManager(title: $_currentQueueTitle, length: ${_mediaItems.length}, index: $_currentIndex)';
}