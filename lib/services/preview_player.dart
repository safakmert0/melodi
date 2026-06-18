import 'dart:async';
import 'package:just_audio/just_audio.dart';

enum PreviewState { stopped, playing, paused }

class PreviewPlayer {
  final AudioPlayer _player = AudioPlayer();
  Timer? _autoStopTimer;
  Timer? _durationTimer;
  PreviewState _state = PreviewState.stopped;
  Duration _remaining = Duration.zero;

  final StreamController<PreviewState> _stateController =
      StreamController<PreviewState>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  Stream<PreviewState> get stateStream => _stateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  PreviewState get state => _state;
  bool get isPreviewActive => _state == PreviewState.playing;

  Future<void> playPreview(String url) async {
    await stopPreview();
    try {
      await _player.setVolume(0.5);
      await _player.setUrl(url);
      _player.play();
      _state = PreviewState.playing;
      _stateController.add(_state);

      _autoStopTimer = Timer(const Duration(seconds: 30), () {
        stopPreview();
      });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final remaining = const Duration(seconds: 30) - _player.position;
        _remaining =
            remaining.isNegative ? Duration.zero : remaining;
        _durationController.add(_remaining);
      });
    } catch (_) {
      _state = PreviewState.stopped;
      _stateController.add(_state);
    }
  }

  Future<void> stopPreview() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    await _player.stop();
    _state = PreviewState.stopped;
    _remaining = Duration.zero;
    _stateController.add(_state);
    _durationController.add(_remaining);
  }

  bool isPlaying() => _state == PreviewState.playing;

  Duration getPreviewDuration() => _remaining;

  void dispose() {
    _autoStopTimer?.cancel();
    _durationTimer?.cancel();
    _player.dispose();
    _stateController.close();
    _durationController.close();
  }
}
