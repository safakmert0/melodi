import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/track_matcher.dart';
import '../services/ytmusic_service.dart';

class YTMusicProvider extends ChangeNotifier {
  final YTMusicService _service;
  bool _isConnecting = false;
  String? _error;

  YTMusicProvider(this._service);

  YTMusicService get service => _service;
  String? get cookie => _service.cookie;
  bool get isConnected => _service.isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;

  Future<void> loadSession() async {
    final db = DatabaseService.instance;
    final savedCookie = await db.getSetting('ytmusic_cookie');
    if (savedCookie != null && savedCookie.isNotEmpty) {
      _service.connectWithCookie(savedCookie);
      notifyListeners();
    }
  }

  Future<bool> connectWithCookie(String cookie) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      _service.connectWithCookie(cookie);
      final db = DatabaseService.instance;
      await db.setSetting('ytmusic_cookie', cookie);
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    _service.disconnect();
    final db = DatabaseService.instance;
    await db.setSetting('ytmusic_cookie', '');
    _error = null;
    notifyListeners();
  }

  Future<List<YTMusicPlaylist>> importPlaylists() async {
    try {
      final playlists = await _service.getLibraryPlaylists();
      return playlists;
    } catch (e) {
      debugPrint('YTMusic importPlaylists error: $e');
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<YTMusicTrack>> importSongs() async {
    try {
      final songs = await _service.getLibrarySongs();
      return songs;
    } catch (e) {
      debugPrint('YTMusic importSongs error: $e');
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<YTMusicTrack>> getPlaylistTracks(String playlistId) async {
    try {
      return await _service.getPlaylistTracks(playlistId);
    } catch (e) {
      debugPrint('YTMusic getPlaylistTracks error: $e');
      return [];
    }
  }

  Future<MatchResult?> matchTrackWithConfidence(
    String title,
    String artist, {
    String? album,
    int? durationMs,
  }) async {
    try {
      return await _service.searchAndMatch(
        title,
        artist,
        album: album,
        durationMs: durationMs,
      );
    } catch (e) {
      debugPrint('matchTrackWithConfidence error: $e');
      return null;
    }
  }
}
