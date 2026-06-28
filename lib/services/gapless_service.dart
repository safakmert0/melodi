import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'database_service.dart';

class GaplessService {
  static final GaplessService _instance = GaplessService._();
  static GaplessService get instance => _instance;
  GaplessService._();

  final DatabaseService _db = DatabaseService.instance;
  final Map<String, AudioSource> _preloadedSources = {};
  Duration _crossfadeDuration = Duration.zero;

  Duration get crossfadeDuration => _crossfadeDuration;

  set crossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
  }

  Future<bool> get isGaplessEnabled async {
    final raw = await _db.getSetting('gapless_playback_enabled');
    return raw == 'true';
  }

  Future<void> setGaplessEnabled(bool enabled) async {
    await _db.setSetting('gapless_playback_enabled', enabled.toString());
  }

  Future<void> preloadNext(List<String> filePaths) async {
    for (final path in filePaths) {
      if (_preloadedSources.containsKey(path)) continue;

      try {
        final source = path.startsWith('http')
            ? AudioSource.uri(Uri.parse(path))
            : AudioSource.file(path);
        _preloadedSources[path] = source;
      } catch (_) {
        continue;
      }
    }
  }

  AudioSource? getCachedSource(String filePath) {
    return _preloadedSources[filePath];
  }

  void clearCache() {
    _preloadedSources.clear();
  }

  void removeFromCache(String filePath) {
    _preloadedSources.remove(filePath);
  }
}