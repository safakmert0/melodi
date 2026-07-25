import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../services/track_matcher.dart';
import '../services/ytmusic_service.dart';

class YTMusicProvider extends ChangeNotifier {
  static const _cookieKey = 'ytmusic_cookie';

  final YTMusicService _service;
  bool _isConnecting = false;
  bool _isInitialized = false;
  String? _error;
  List<YTMusicPlaylist> _playlists = [];

  YTMusicProvider(this._service);

  YTMusicService get service => _service;
  String? get cookie => _service.cookie;
  bool get isConnected => _service.isConnected;
  bool get isConnecting => _isConnecting;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<YTMusicPlaylist> get playlists => _playlists;

  Future<void> loadSession() async {
    try {
      final db = DatabaseService.instance;
      var savedCookie = await SecureStorageService.instance.read(_cookieKey);
      if (savedCookie == null || savedCookie.isEmpty) {
        savedCookie = await db.getSetting(_cookieKey);
        if (savedCookie != null && savedCookie.isNotEmpty) {
          await SecureStorageService.instance.write(_cookieKey, savedCookie);
          await db.deleteSetting(_cookieKey);
        }
      }
      if (savedCookie != null && savedCookie.isNotEmpty) {
        if (_service.connectWithCookie(savedCookie)) {
          await _loadPlaylists();
        } else {
          await SecureStorageService.instance.delete(_cookieKey);
          await db.deleteSetting(_cookieKey);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final db = DatabaseService.instance;
      final saved = await db.getSetting('ytmusic_playlists');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        _playlists = decoded
            .map((e) => YTMusicPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('YTMusic _loadPlaylists error: $e');
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final db = DatabaseService.instance;
      final encoded = jsonEncode(_playlists.map((p) => p.toJson()).toList());
      await db.setSetting('ytmusic_playlists', encoded);
    } catch (e) {
      debugPrint('YTMusic _savePlaylists error: $e');
    }
  }

  Future<bool> connectWithCookie(String cookie) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      if (!_service.connectWithCookie(cookie) ||
          !await _service.validateConnection()) {
        _error = 'Invalid or expired YouTube Music cookie';
        return false;
      }
      final db = DatabaseService.instance;
      await SecureStorageService.instance.write(_cookieKey, cookie);
      await db.deleteSetting(_cookieKey);
      return true;
    } catch (e) {
      _service.disconnect();
      _error = e.toString();
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _service.disconnect();
    final db = DatabaseService.instance;
    await SecureStorageService.instance.delete(_cookieKey);
    await db.deleteSetting(_cookieKey);
    await db.setSetting('ytmusic_playlists', '');
    _playlists = [];
    _error = null;
    notifyListeners();
  }

  Future<List<YTMusicPlaylist>> importPlaylists() async {
    try {
      final playlists = await _service.getLibraryPlaylists();
      _playlists = playlists;
      await _savePlaylists();
      notifyListeners();
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
