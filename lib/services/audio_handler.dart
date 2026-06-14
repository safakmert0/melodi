import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'database_service.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  final AudioPlayer _player = AudioPlayer();
  final DatabaseService _db = DatabaseService.instance;

  List<SongModel> _queue = [];
  List<SongModel> _originalQueue = [];
  int _currentIndex = -1;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _isInitialized = false;

  AudioPlayerHandler() {
    _initPlayer();
  }

  void _initPlayer() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackComplete();
      }
      _broadcastState();
    });

    _player.positionStream.listen((_) {
      _broadcastState();
    });

    _player.durationStream.listen((duration) {
      if (duration != null && _currentIndex >= 0 && _currentIndex < _queue.length) {
        mediaItem.add(mediaItem.value?.copyWith(duration: duration));
      }
    });
  }

  void _broadcastState() {
    if (!_isInitialized) return;
    final index = _currentIndex;
    if (index < 0 || index >= _queue.length) return;

    final isPlaying = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: index,
    ));
  }

  List<SongModel> get queue => List.unmodifiable(_queue);
  List<SongModel> get originalQueue => List.unmodifiable(_originalQueue);
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  bool get isShuffled => _isShuffled;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _player.position;
  Duration get bufferedPosition => _player.bufferedPosition;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get durationStream => _player.durationStream.map((d) => d ?? Duration.zero);
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  Future<void> playSong(SongModel song) async {
    await setQueue([song], initialIndex: 0);
  }

  Future<void> setQueue(List<SongModel> songs,
      {int initialIndex = 0}) async {
    _originalQueue = List.from(songs);
    _queue = List.from(songs);
    _currentIndex = initialIndex;

    if (_isShuffled && songs.length > 1) {
      _applyShuffle();
    }

    await _playCurrent();
  }

  Future<void> playFromQueue(List<SongModel> songs, int index) async {
    await setQueue(songs, initialIndex: index);
  }

  Future<void> addToQueue(SongModel song) async {
    _originalQueue.add(song);
    if (_isShuffled) {
      _queue.add(song);
    } else {
      _queue.add(song);
    }
    await _updateMediaQueue();
  }

  Future<void> insertNext(SongModel song) async {
    if (_currentIndex + 1 <= _queue.length) {
      _queue.insert(_currentIndex + 1, song);
      _originalQueue.insert(_currentIndex + 1, song);
    }
    await _updateMediaQueue();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (index == _currentIndex) return;

    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    }
    await _updateMediaQueue();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    _originalQueue.clear();
    _currentIndex = -1;
    await _player.stop();
    await _updateMediaQueue();
  }

  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      _applyShuffle();
    } else {
      _unapplyShuffle();
    }
  }

  void _applyShuffle() {
    if (_queue.isEmpty) return;
    final currentSong = _currentIndex >= 0 ? _queue[_currentIndex] : null;
    final remaining =
        _queue.where((s) => s.id != currentSong?.id).toList();
    remaining.shuffle();
    _queue = currentSong != null ? [currentSong, ...remaining] : remaining;
    _currentIndex = 0;
  }

  void _unapplyShuffle() {
    final currentSong = _currentIndex >= 0 ? _queue[_currentIndex] : null;
    _queue = List.from(_originalQueue);
    _currentIndex = currentSong != null
        ? _queue.indexWhere((s) => s.id == currentSong.id)
        : 0;
    if (_currentIndex == -1) _currentIndex = 0;
  }

  Future<void> _setRepeatMode(RepeatMode mode) async {
    _repeatMode = mode;
    switch (mode) {
      case RepeatMode.off:
        _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekForward() async {
    final newPos = _player.position + const Duration(seconds: 10);
    final dur = _player.duration ?? Duration.zero;
    await _player.seek(newPos > dur ? dur : newPos);
  }

  Future<void> seekBackward() async {
    final newPos = _player.position - const Duration(seconds: 10);
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _onTrackComplete() {
    if (_repeatMode == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex < _queue.length) {
      _currentIndex = nextIndex;
      _playCurrent();
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
      _playCurrent();
    }
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    _isInitialized = false;
    final song = _queue[_currentIndex];

    try {
      await _player.setAudioSource(
        AudioSource.file(song.filePath),
        preload: true,
        initialPosition: Duration.zero,
      );
      await _player.play();

      final mediaItem = MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: null,
      );

      this.mediaItem.add(mediaItem);
      super.mediaItem.add(mediaItem);

      await _db.updatePlayCount(song.id);
      _isInitialized = true;
    } catch (e) {
      _isInitialized = true;
      _onTrackComplete();
    }
  }

  Future<void> _updateMediaQueue() async {
    final items = _queue
        .map((song) => MediaItem(
              id: song.id,
              album: song.album,
              title: song.title,
              artist: song.artist,
              duration: song.duration,
            ))
        .toList();
    queue.add(items);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await _playCurrent();
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
      await _playCurrent();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
    }
  }

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.all && !_isShuffled) {
      await toggleShuffle();
    } else if (shuffleMode == AudioServiceShuffleMode.none && _isShuffled) {
      await toggleShuffle();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _setRepeatMode(RepeatMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _setRepeatMode(RepeatMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _setRepeatMode(RepeatMode.all);
        break;
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'seekForward':
        await seekForward();
        break;
      case 'seekBackward':
        await seekBackward();
        break;
    }
  }

  @override
  Future<int> addQueueItem(MediaItem mediaItem) async {
    final song = _queue.firstWhere(
      (s) => s.id == mediaItem.id,
      orElse: () => _queue[0],
    );
    if (song.id == mediaItem.id) {
      await addToQueue(song);
      return _queue.length - 1;
    }
    return -1;
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await removeFromQueue(index);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.play]) async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  void dispose() {
    _player.dispose();
  }
}

enum RepeatMode { off, all, one }
