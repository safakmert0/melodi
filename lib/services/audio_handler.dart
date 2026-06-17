import 'dart:async';
import 'package:collection/collection.dart';
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
  LoopStyle _repeatMode = LoopStyle.off;
  bool _isInitialized = false;
  bool _autoShuffleEnabled = false;
  bool _gaplessPlaybackEnabled = false;
  Duration _crossfadeDuration = Duration.zero;
  Timer? _sleepTimer;

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
      if (_isInitialized) _broadcastState();
    });

    _player.durationStream.listen((duration) {
      if (duration != null && _currentIndex >= 0 && _currentIndex < _queue.length) {
        mediaItem.add(mediaItem.value?.copyWith(duration: duration));
      }
    });

    _player.playingStream.listen((_) {
      _broadcastState();
    });

    _player.processingStateStream.listen((_) {
      _broadcastState();
    });
  }

  void _broadcastState() {
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
      queueIndex: index,
    ));
  }

  List<SongModel> get songQueue => List.unmodifiable(_queue);
  List<SongModel> get originalQueue => List.unmodifiable(_originalQueue);
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  bool get isShuffled => _isShuffled;
  LoopStyle get repeatMode => _repeatMode;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get bufferedPosition => _player.bufferedPosition;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  double get playbackSpeed => _player.speed;
  double get volume => _player.volume;
  bool get gaplessPlaybackEnabled => _gaplessPlaybackEnabled;
  Duration get crossfadeDuration => _crossfadeDuration;
  bool get autoShuffleEnabled => _autoShuffleEnabled;

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

  void updateSongInQueue(SongModel song) {
    final origIdx = _originalQueue.indexWhere((s) => s.id == song.id);
    if (origIdx != -1) _originalQueue[origIdx] = song;
    final idx = _queue.indexWhere((s) => s.id == song.id);
    if (idx != -1) _queue[idx] = song;
  }

  Future<void> addToQueue(SongModel song) async {
    _originalQueue.add(song);
    _queue.add(song);
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

  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
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

  Future<void> setLoopStyle(LoopStyle mode) async {
    _repeatMode = mode;
    switch (mode) {
      case LoopStyle.off:
        _player.setLoopMode(LoopMode.off);
        break;
      case LoopStyle.all:
        _player.setLoopMode(LoopMode.all);
        break;
      case LoopStyle.one:
        _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> seekForward([bool immediate = true]) async {
    final offset = Duration(seconds: immediate ? 10 : 30);
    final newPos = _player.position + offset;
    final dur = _player.duration ?? Duration.zero;
    await _player.seek(newPos > dur ? dur : newPos);
  }

  @override
  Future<void> seekBackward([bool immediate = true]) async {
    final offset = Duration(seconds: immediate ? 10 : 30);
    final newPos = _player.position - offset;
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _onTrackComplete() {
    if (_repeatMode == LoopStyle.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex < _queue.length) {
      _currentIndex = nextIndex;
      _playCurrent();
    } else if (_repeatMode == LoopStyle.all) {
      _currentIndex = 0;
      _playCurrent();
    }
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    _isInitialized = false;
    final song = _queue[_currentIndex];

    try {
      final audioSource = song.filePath.startsWith('http')
          ? AudioSource.uri(Uri.parse(song.filePath))
          : AudioSource.file(song.filePath);
      await _player.setAudioSource(
        audioSource,
        preload: true,
        initialPosition: Duration.zero,
      );

      if (_playbackSpeedOverride != null) {
        await _player.setSpeed(_playbackSpeedOverride!);
      }
      if (_volumeOverride != null) {
        await _player.setVolume(_volumeOverride!.clamp(0.5, 2.0));
      }

      await _player.play();

      if (_player.playing) {
        if (_currentIndex < 0 || _currentIndex >= _queue.length) {
          _currentIndex = _queue.isNotEmpty ? 0 : -1;
        }
      }

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
      _broadcastState();
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
    super.queue.add(items);
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
    } else if (_repeatMode == LoopStyle.all) {
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

  double? _playbackSpeedOverride;
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeedOverride = speed;
    await _player.setSpeed(speed);
  }

  double? _volumeOverride;
  Future<void> setVolume(double boost) async {
    _volumeOverride = boost.clamp(0.5, 2.0);
    await _player.setVolume(_volumeOverride!);
  }

  Future<void> enableGaplessPlayback() async {
    _gaplessPlaybackEnabled = true;
  }

  Future<void> disableGaplessPlayback() async {
    _gaplessPlaybackEnabled = false;
  }

  Future<void> setGaplessPlaybackEnabled(bool enabled) async {
    if (enabled) {
      await enableGaplessPlayback();
    } else {
      await disableGaplessPlayback();
    }
  }

  Future<void> setCrossfade(Duration duration) async {
    _crossfadeDuration = duration;
  }

  Future<void> setAutoShuffle(bool enabled) async {
    _autoShuffleEnabled = enabled;
    if (enabled && !_isShuffled) {
      await toggleShuffle();
    }
  }

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
        await setLoopStyle(LoopStyle.off);
        break;
      case AudioServiceRepeatMode.one:
        await setLoopStyle(LoopStyle.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await setLoopStyle(LoopStyle.all);
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
    final song = _queue.firstWhereOrNull((s) => s.id == mediaItem.id);
    if (song != null) {
      await addToQueue(song);
      return _queue.length - 1;
    }
    return -1;
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await removeFromQueue(index);
  }

  Future<void> setSleepTimer(Duration duration) async {
    _sleepTimer?.cancel();
    if (duration == Duration.zero) return;
    _sleepTimer = Timer(duration, () {
      _player.pause();
      _sleepTimer = null;
    });
  }

  @override
  Future<void> click([MediaButton? button]) async {
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
enum LoopStyle { off, all, one }
