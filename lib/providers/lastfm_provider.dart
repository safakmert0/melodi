import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/lastfm_service.dart';

class LastFmProvider extends ChangeNotifier {
  final LastFmService _service;
  bool _isConnecting = false;
  String? _authToken;
  String? _authUrl;
  String? _error;

  LastFmProvider(this._service);

  LastFmService get service => _service;
  bool get isConnected => _service.isConnected;
  bool get isConnecting => _isConnecting;
  String? get username => _service.session?.username;
  String? get error => _error;

  Future<void> loadSession() async {
    final db = DatabaseService.instance;
    final username = await db.getSetting('lastfm_username');
    final sessionKey = await db.getSetting('lastfm_session_key');
    if (username != null && sessionKey != null) {
      _service.setSession(LastFmSession(
        username: username,
        sessionKey: sessionKey,
      ));
      notifyListeners();
    }
  }

  Future<void> startAuth() async {
    _isConnecting = true;
    _error = null;
    notifyListeners();
    try {
      _authToken = await _service.getAuthToken();
      _authUrl = _service.getAuthUrl(_authToken!);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<bool> completeAuth() async {
    if (_authToken == null) return false;
    try {
      final session = await _service.getSession(_authToken!);
      _service.setSession(session);
      final db = DatabaseService.instance;
      await db.setSetting('lastfm_username', session.username);
      await db.setSetting('lastfm_session_key', session.sessionKey);
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
    _service.setSession(null);
    final db = DatabaseService.instance;
    await db.setSetting('lastfm_username', '');
    await db.setSetting('lastfm_session_key', '');
    _authToken = null;
    _authUrl = null;
    _error = null;
    notifyListeners();
  }

  Future<void> scrobble({
    required String artist,
    required String track,
    required int timestamp,
    String? album,
  }) async {
    if (!_service.isConnected) return;
    try {
      await _service.scrobble(
        artist: artist,
        track: track,
        timestamp: timestamp,
        album: album,
      );
    } catch (e) {
      debugPrint('Scrobble failed: $e');
    }
  }

  Future<void> updateNowPlaying({
    required String artist,
    required String track,
    String? album,
  }) async {
    if (!_service.isConnected) return;
    try {
      await _service.updateNowPlaying(
        artist: artist,
        track: track,
        album: album,
      );
    } catch (e) {
      debugPrint('NowPlaying update failed: $e');
    }
  }
}
