import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class SleepTimerState {
  final int remainingSeconds;
  final bool isActive;

  const SleepTimerState({
    required this.remainingSeconds,
    required this.isActive,
  });
}

class EqualizerPreset {
  final String name;
  final String label;
  final List<double> bands;

  const EqualizerPreset({
    required this.name,
    required this.label,
    required this.bands,
  });
}

class PlaybackService {
  static final PlaybackService _instance = PlaybackService._();
  static PlaybackService get instance => _instance;
  PlaybackService._();

  final DatabaseService _db = DatabaseService.instance;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  final StreamController<SleepTimerState> _sleepTimerController =
      StreamController<SleepTimerState>.broadcast();
  Timer? _sleepTickTimer;

  Stream<SleepTimerState> get sleepTimerStream => _sleepTimerController.stream;

  static const List<EqualizerPreset> equalizerPresets = [
    EqualizerPreset(name: 'normal', label: 'Normal', bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    EqualizerPreset(name: 'pop', label: 'Pop', bands: [2, 3, 5, 4, 2, 0, -1, -1, 0, 1]),
    EqualizerPreset(name: 'rock', label: 'Rock', bands: [5, 4, 2, -1, -2, -1, 1, 3, 4, 4]),
    EqualizerPreset(name: 'jazz', label: 'Jazz', bands: [3, 2, 1, 1, 2, 3, 2, 1, 1, 2]),
    EqualizerPreset(name: 'classical', label: 'Classical', bands: [4, 3, 2, 1, 0, 0, 1, 2, 3, 4]),
    EqualizerPreset(name: 'bass_boost', label: 'Bass Boost', bands: [6, 5, 4, 2, 0, -1, -2, -2, -1, 0]),
    EqualizerPreset(name: 'vocal', label: 'Vocal', bands: [-2, -1, 1, 3, 5, 5, 3, 1, -1, -2]),
  ];

  static const List<String> eqBandLabels = [
    '60 Hz', '170 Hz', '310 Hz', '600 Hz', '1 kHz',
    '3 kHz', '6 kHz', '12 kHz', '14 kHz', '16 kHz',
  ];

  Future<void> startSleepTimer(int minutes) async {
    _sleepTimer?.cancel();
    _sleepTickTimer?.cancel();
    _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(_sleepTimerEnd!.difference(DateTime.now()), () {
      _onSleepTimerEnd();
    });
    _sleepTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitSleepTimerState();
    });
    await _db.setSetting('sleep_timer_end', _sleepTimerEnd!.toIso8601String());
    _emitSleepTimerState();
  }

  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTickTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    await _db.setSetting('sleep_timer_end', '');
    _emitSleepTimerState();
  }

  Duration getRemainingTime() {
    if (_sleepTimerEnd == null) return Duration.zero;
    final remaining = _sleepTimerEnd!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isSleepTimerActive => _sleepTimerEnd != null;

  void _onSleepTimerEnd() {
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _sleepTickTimer?.cancel();
    _sleepTickTimer = null;
    _emitSleepTimerState();
  }

  void _emitSleepTimerState() {
    final remaining = getRemainingTime();
    _sleepTimerController.add(SleepTimerState(
      remainingSeconds: remaining.inSeconds,
      isActive: isSleepTimerActive,
    ));
  }

  Future<void> restoreSleepTimer() async {
    final raw = await _db.getSetting('sleep_timer_end');
    if (raw != null && raw.isNotEmpty) {
      final end = DateTime.tryParse(raw);
      if (end != null && end.isAfter(DateTime.now())) {
        _sleepTimerEnd = end;
        final remaining = _sleepTimerEnd!.difference(DateTime.now());
        _sleepTimer = Timer(remaining, _onSleepTimerEnd);
        _sleepTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _emitSleepTimerState();
        });
        _emitSleepTimerState();
      } else {
        await _db.setSetting('sleep_timer_end', '');
      }
    }
  }

  Future<Duration> getCrossfadeDuration() async {
    final raw = await _db.getSetting('crossfade_seconds');
    if (raw != null) {
      final seconds = int.tryParse(raw) ?? 0;
      return Duration(seconds: seconds.clamp(0, 12));
    }
    return Duration.zero;
  }

  Future<void> setCrossfadeDuration(Duration duration) async {
    final seconds = duration.inSeconds.clamp(0, 12);
    await _db.setSetting('crossfade_seconds', seconds.toString());
  }

  List<EqualizerPreset> getEqualizerPresets() {
    return List.unmodifiable(equalizerPresets);
  }

  Future<String> getActiveEQPreset() async {
    final raw = await _db.getSetting('eq_preset');
    return raw ?? 'normal';
  }

  Future<void> setEqualizerPreset(String name) async {
    await _db.setSetting('eq_preset', name);
  }

  Future<List<double>> getCustomEQ() async {
    final raw = await _db.getSetting('eq_custom_bands');
    if (raw != null && raw.isNotEmpty) {
      final parts = raw.split(',');
      if (parts.length == 10) {
        return parts.map((p) => double.tryParse(p) ?? 0).toList();
      }
    }
    return List.filled(10, 0);
  }

  Future<void> setCustomEQ(List<double> bands) async {
    if (bands.length != 10) return;
    await _db.setSetting('eq_custom_bands', bands.map((b) => b.toStringAsFixed(1)).join(','));
    await _db.setSetting('eq_preset', 'custom');
  }

  Future<bool> getEQEnabled() async {
    final raw = await _db.getSetting('eq_enabled');
    return raw == 'true';
  }

  Future<void> setEQEnabled(bool enabled) async {
    await _db.setSetting('eq_enabled', enabled.toString());
  }

  Future<List<double>> getAppliedEQBands() async {
    final raw = await _db.getSetting('eq_preset');
    final name = raw ?? 'normal';
    if (name == 'custom') {
      return getCustomEQ();
    }
    final preset = equalizerPresets.firstWhere(
      (p) => p.name == name,
      orElse: () => equalizerPresets.first,
    );
    return preset.bands;
  }

  void dispose() {
    _sleepTimer?.cancel();
    _sleepTickTimer?.cancel();
    _sleepTimerController.close();
  }
}
