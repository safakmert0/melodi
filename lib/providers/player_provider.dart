import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/audio_handler.dart';
import '../services/database_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerHandler _handler;
  final DatabaseService _db = DatabaseService.instance;

  PlayerProvider(this._handler) {
    _setupListeners();
  }

  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;

  AudioPlayerHandler get handler => _handler;

  SongModel? get currentSong => _handler.currentSong;
  List<SongModel> get queue => _handler.queue;
  bool get isPlaying => _handler.playbackState.value.playing;
  bool get isShuffled => _handler.isShuffled;
  RepeatMode get repeatMode => _handler.repeatMode;
  Duration get position => _handler.position;
  Duration get duration => _handler.duration;
  int get currentIndex => _handler.currentIndex;
  Stream<Duration> get positionStream => _handler.positionStream;
  Stream<Duration> get durationStream => _handler.durationStream;

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
  }

  Future<void> playSong(SongModel song) async {
    await _handler.playSong(song);
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
    if (_handler.playbackState.value.playing) {
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
      case RepeatMode.off:
        await _handler._setRepeatMode(RepeatMode.all);
        break;
      case RepeatMode.all:
        await _handler._setRepeatMode(RepeatMode.one);
        break;
      case RepeatMode.one:
        await _handler._setRepeatMode(RepeatMode.off);
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

  Future<void> setVolume(double volume) async {
    await _handler.setSpeed(volume);
    notifyListeners();
  }

  void seekRelative(double fraction) {
    if (_handler.duration.inMilliseconds > 0) {
      final pos = Duration(
          milliseconds: (fraction * _handler.duration.inMilliseconds).round());
      seek(pos);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }
}
