import 'package:flutter/material.dart';
import 'database_service.dart';

class ResumePlaybackState {
  final String trackId;
  final String title;
  final String artist;
  final Duration position;
  final String source;
  final DateTime savedAt;

  ResumePlaybackState({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.position,
    this.source = '',
    required this.savedAt,
  });
}

class ResumePlayback extends ChangeNotifier {
  ResumePlaybackState? _state;
  bool _isLoading = false;

  ResumePlaybackState? get state => _state;
  bool get hasState => _state != null;
  bool get isLoading => _isLoading;

  Future<void> savePlaybackState(
    String trackId,
    String title,
    String artist,
    Duration position,
    String source,
  ) async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    await db.setSetting('resume_track_id', trackId);
    await db.setSetting('resume_title', title);
    await db.setSetting('resume_artist', artist);
    await db.setSetting('resume_position_ms', position.inMilliseconds.toString());
    await db.setSetting('resume_source', source);
    await db.setSetting('resume_saved_at', now.toIso8601String());

    _state = ResumePlaybackState(
      trackId: trackId,
      title: title,
      artist: artist,
      position: position,
      source: source,
      savedAt: now,
    );
    notifyListeners();
  }

  Future<ResumePlaybackState?> restorePlaybackState() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = DatabaseService.instance;
      final trackId = await db.getSetting('resume_track_id');
      if (trackId == null || trackId.isEmpty) {
        _state = null;
        return null;
      }

      final title = await db.getSetting('resume_title') ?? '';
      final artist = await db.getSetting('resume_artist') ?? '';
      final positionMsStr = await db.getSetting('resume_position_ms') ?? '0';
      final positionMs = int.tryParse(positionMsStr) ?? 0;
      final source = await db.getSetting('resume_source') ?? '';
      final savedAtStr = await db.getSetting('resume_saved_at');
      final savedAt =
          savedAtStr != null ? DateTime.parse(savedAtStr) : DateTime.now();

      if (_isExpired(savedAt)) {
        await clearPlaybackState();
        _state = null;
        return null;
      }

      _state = ResumePlaybackState(
        trackId: trackId,
        title: title,
        artist: artist,
        position: Duration(milliseconds: positionMs),
        source: source,
        savedAt: savedAt,
      );
      return _state;
    } catch (_) {
      _state = null;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> hasResumablePlayback() async {
    final state = await restorePlaybackState();
    return state != null;
  }

  Future<void> clearPlaybackState() async {
    final db = DatabaseService.instance;
    await db.setSetting('resume_track_id', '');
    await db.setSetting('resume_title', '');
    await db.setSetting('resume_artist', '');
    await db.setSetting('resume_position_ms', '0');
    await db.setSetting('resume_source', '');
    await db.setSetting('resume_saved_at', '');
    _state = null;
    notifyListeners();
  }

  bool _isExpired(DateTime savedAt) {
    final age = DateTime.now().difference(savedAt);
    return age.inHours >= 24;
  }
}
