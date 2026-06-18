import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/spotify_service.dart';

class SpotifyProvider extends ChangeNotifier {
  final SpotifyService _service = SpotifyService();
  bool _isConnecting = false;
  String? _spDc;
  String? _username;
  List<SpotifyPlaylistItem> _playlists = [];
  List<SpotifyTrackItem> _likedSongs = [];
  bool _isImportingPlaylists = false;
  bool _isImportingLikedSongs = false;
  String? _error;

  SpotifyService get service => _service;
  bool get isConnected => _service.isConnected;
  bool get isConnecting => _isConnecting;
  String? get username => _username;
  List<SpotifyPlaylistItem> get playlists => _playlists;
  List<SpotifyTrackItem> get likedSongs => _likedSongs;
  bool get isImportingPlaylists => _isImportingPlaylists;
  bool get isImportingLikedSongs => _isImportingLikedSongs;
  String? get error => _error;

  Future<void> init() async {
    final db = DatabaseService.instance;
    final spDc = await db.getSetting('spotify_sp_dc');
    if (spDc != null && spDc.isNotEmpty) {
      _spDc = spDc;
      final session = await _service.getAccessToken(spDc);
      if (session != null) {
        _username = session.username;
        notifyListeners();
      } else {
        _spDc = null;
        await db.setSetting('spotify_sp_dc', '');
      }
    }
  }

  Future<bool> connectWithCookie(String spDc) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _service.getAccessToken(spDc);
      if (session == null) {
        _error = 'Invalid or expired sp_dc cookie';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      _spDc = spDc;
      _username = session.username;

      final db = DatabaseService.instance;
      await db.setSetting('spotify_sp_dc', spDc);

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
    _spDc = null;
    _username = null;
    _playlists = [];
    _likedSongs = [];
    _error = null;

    final db = DatabaseService.instance;
    await db.setSetting('spotify_sp_dc', '');

    notifyListeners();
  }

  Future<List<SpotifyPlaylistItem>> importPlaylists() async {
    _isImportingPlaylists = true;
    _error = null;
    notifyListeners();

    try {
      if (_service.isExpiringSoon) {
        await _service.refreshAccessToken();
      }

      _playlists = await _service.getUserPlaylists();
      notifyListeners();
      return _playlists;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    } finally {
      _isImportingPlaylists = false;
      notifyListeners();
    }
  }

  Future<List<SpotifyTrackItem>> importLikedSongs() async {
    _isImportingLikedSongs = true;
    _error = null;
    notifyListeners();

    try {
      if (_service.isExpiringSoon) {
        await _service.refreshAccessToken();
      }

      _likedSongs = await _service.getLikedSongs();
      notifyListeners();
      return _likedSongs;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    } finally {
      _isImportingLikedSongs = false;
      notifyListeners();
    }
  }
}
