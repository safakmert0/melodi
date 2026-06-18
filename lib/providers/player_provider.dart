import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/audio_handler.dart';
import '../services/database_service.dart';
import '../services/carplay_service.dart';

typedef ScrobbleCallback = void Function(SongModel song, int timestamp);

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerHandler _handler;
  final DatabaseService _db = DatabaseService.instance;
  Timer? _periodicTimer;
  Timer? _scrobbleTimer;
  DateTime? _playStartTime;
  ScrobbleCallback? onScrobble;
  VoidCallback? onNowPlaying;

  bool _streamingEnabled = true;
  bool _autoSkipOffline = false;

  bool get streamingEnabled => _streamingEnabled;

  PlayerProvider(this._handler) {
    _setupListeners();
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (hasListeners) notifyListeners();
    });
  }

  void setStreamingEnabled(bool enabled) {
    _streamingEnabled = enabled;
    if (!enabled) {
      _filterQueueToDownloaded();
    }
    notifyListeners();
  }

  void _filterQueueToDownloaded() {
    if (_handler.songQueue.isEmpty) return;
    final filtered = _handler.songQueue.where((s) => _isDownloaded(s)).toList();
    if (filtered.length < _handler.songQueue.length) {
      _handler.songQueue
        ..clear()
        ..addAll(filtered);
    }
  }

  bool _isDownloaded(SongModel song) {
    try {
      return File(song.filePath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> checkAndSkipOffline() async {
    if (_streamingEnabled) return;
    final song = _handler.currentSong;
    if (song != null && !_isDownloaded(song)) {
      await skipToNext();
    }
  }

  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _processingSub;

  AudioPlayerHandler get handler => _handler;

  SongModel? get currentSong => _handler.currentSong;

  void updateCurrentSong(SongModel song) {
    _handler.updateSongInQueue(song);
    notifyListeners();
  }

  List<SongModel> get queue => _handler.songQueue;
  bool get isPlaying => _handler.isPlaying;
  bool get isShuffled => _handler.isShuffled;
  LoopStyle get repeatMode => _handler.repeatMode;
  Duration get position => _handler.position;
  Duration get duration => _handler.duration;
  int get currentIndex => _handler.currentIndex;
  double get playbackSpeed => _handler.playbackSpeed;
  double get volumeBoost => _handler.volume;
  bool get hasActivePlayback => _handler.currentSong != null || _handler.isPlaying;
  int? get sleepTimerMinutes => _handler.sleepTimerMinutes;

  set playbackSpeed(double speed) {
    _handler.setPlaybackSpeed(speed);
    notifyListeners();
  }
  bool get autoShuffleEnabled => _handler.autoShuffleEnabled;
  bool get gaplessPlaybackEnabled => _handler.gaplessPlaybackEnabled;
  Duration get crossfadeDuration => _handler.crossfadeDuration;

  Stream<Duration> get positionStream => _handler.positionStream;
  Stream<Duration?> get durationStream => _handler.durationStream;
  Stream<bool> get playingStream => _handler.playingStream;

  set volume(double volume) {
    _handler.setVolume(volume);
    notifyListeners();
  }

  void _setupListeners() {
    _positionSub = _handler.positionStream.listen((_) {
      if (hasListeners) notifyListeners();
    });
    _stateSub = _handler.playerStateStream.listen((_) {
      if (hasListeners) notifyListeners();
    });
    _durationSub = _handler.durationStream.listen((_) {
      if (hasListeners) notifyListeners();
    });
    _playingSub = _handler.playingStream.listen((_) {
      if (hasListeners) notifyListeners();
    });
    _processingSub = _handler.processingStateStream.listen((_) {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> playSong(SongModel song) async {
    await _handler.playSong(song);
    _playStartTime = DateTime.now();
    _startScrobbleTimer(song);
    CarPlayService.updateNowPlaying(song);
    onNowPlaying?.call();
    notifyListeners();
  }

  Future<void> playFromQueue(List<SongModel> songs, int index) async {
    await _handler.playFromQueue(songs, index);
    notifyListeners();
  }

  Future<void> play() async {
    await _handler.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _handler.pause();
    notifyListeners();
  }

  Future<void> playPause() async {
    if (_handler.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skipToNext() async {
    await _handler.skipToNext();
    notifyListeners();
  }

  Future<void> skipToPrevious() async {
    await _handler.skipToPrevious();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _handler.seek(position);
    notifyListeners();
  }

  Future<void> seekForward() async {
    await _handler.seekForward();
    notifyListeners();
  }

  Future<void> seekBackward() async {
    await _handler.seekBackward();
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
    notifyListeners();
  }

  Future<void> cycleRepeatMode() async {
    switch (_handler.repeatMode) {
      case LoopStyle.off:
        await _handler.setLoopStyle(LoopStyle.all);
        break;
      case LoopStyle.all:
        await _handler.setLoopStyle(LoopStyle.one);
        break;
      case LoopStyle.one:
        await _handler.setLoopStyle(LoopStyle.off);
        break;
    }
    notifyListeners();
  }

  Future<void> addToQueue(SongModel song) async {
    await _handler.addToQueue(song);
    notifyListeners();
  }

  Future<void> insertNext(SongModel song) async {
    await _handler.insertNext(song);
    notifyListeners();
  }

  Future<void> clearQueue() async {
    await _handler.clearQueue();
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    await _handler.removeFromQueue(index);
    notifyListeners();
  }

  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    await _handler.moveInQueue(oldIndex, newIndex);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _handler.setPlaybackSpeed(speed);
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    await _handler.setVolume(volume);
    notifyListeners();
  }

  Future<void> setAutoShuffle(bool enabled) async {
    await _handler.setAutoShuffle(enabled);
    notifyListeners();
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    await _handler.setGaplessPlaybackEnabled(enabled);
    notifyListeners();
  }

  Future<void> setCrossfade(Duration duration) async {
    await _handler.setCrossfade(duration);
    notifyListeners();
  }

  void seekRelative(double fraction) {
    if (_handler.duration.inMilliseconds > 0) {
      final pos = Duration(
          milliseconds: (fraction * _handler.duration.inMilliseconds).round());
      seek(pos);
    }
  }

  void _startScrobbleTimer(SongModel song) {
    _scrobbleTimer?.cancel();
    final duration = _handler.duration;
    if (duration.inSeconds < 30) return;
    final scrobbleAt = duration.inMilliseconds ~/ 2;
    if (scrobbleAt <= 0) return;
    _scrobbleTimer = Timer(Duration(milliseconds: scrobbleAt), () {
      if (_handler.currentSong?.id == song.id && _handler.isPlaying) {
        final timestamp = (_playStartTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch) ~/ 1000;
        onScrobble?.call(song, timestamp);
      }
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _scrobbleTimer?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _processingSub?.cancel();
    super.dispose();
  }
}
