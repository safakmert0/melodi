import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/lastfm_service.dart';

class LastFmProvider extends ChangeNotifier {
  LastFmService? _service;
  bool _isConnecting = false;
  String? _authToken;
  String? _authUrl;
  String? _error;
  bool _scrobbleEnabled = true;
  DateTime? _lastScrobbledAt;

  LastFmService get service {
    if (_service == null) {
      _service = LastFmService(apiKey: '', apiSecret: '');
      _loadCredentials();
    }
    return _service!;
  }

  bool get isConnected => _service?.isConnected ?? false;
  bool get isConnecting => _isConnecting;
  String? get username => _service?.session?.username;
  String? get sessionKey => _service?.session?.sessionKey;
  String? get error => _error;
  bool get scrobbleEnabled => _scrobbleEnabled;
  DateTime? get lastScrobbledAt => _lastScrobbledAt;

  Future<void> _loadCredentials() async {
    final db = DatabaseService.instance;
    final apiKey = await db.getSetting('lastfm_api_key');
    final apiSecret = await db.getSetting('lastfm_api_secret');
    if (apiKey != null && apiKey.isNotEmpty && apiSecret != null && apiSecret.isNotEmpty) {
      _service?.setCredentials(apiKey, apiSecret);
    }
    final enabled = await db.getSetting('lastfm_scrobble_enabled');
    if (enabled != null) {
      _scrobbleEnabled = enabled == 'true';
    }
    final lastAt = await db.getSetting('lastfm_last_scrobbled_at');
    if (lastAt != null && lastAt.isNotEmpty) {
      _lastScrobbledAt = DateTime.tryParse(lastAt);
    }
  }

  Future<void> loadSession() async {
    await _loadCredentials();
    final db = DatabaseService.instance;
    final username = await db.getSetting('lastfm_username');
    final sessionKey = await db.getSetting('lastfm_session_key');
    if (username != null && sessionKey != null && username.isNotEmpty && sessionKey.isNotEmpty) {
      _service?.setSession(LastFmSession(
        username: username,
        sessionKey: sessionKey,
      ));
      notifyListeners();
    }
  }

  Future<bool> connect(String apiKey, String apiSecret) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      _service ??= LastFmService(apiKey: apiKey, apiSecret: apiSecret);
      _service!.setCredentials(apiKey, apiSecret);

      final token = await _service!.getAuthToken();
      final session = await _service!.getSession(token);

      _service!.setSession(session);

      final db = DatabaseService.instance;
      await db.setSetting('lastfm_api_key', apiKey);
      await db.setSetting('lastfm_api_secret', apiSecret);
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

  Future<void> startAuth() async {
    if (_service == null) return;
    _isConnecting = true;
    _error = null;
    notifyListeners();
    try {
      _authToken = await _service!.getAuthToken();
      _authUrl = _service!.getAuthUrl(_authToken!);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<bool> completeAuth() async {
    if (_authToken == null || _service == null) return false;
    try {
      final session = await _service!.getSession(_authToken!);
      _service!.setSession(session);
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
    _service?.setSession(null);
    final db = DatabaseService.instance;
    await db.setSetting('lastfm_username', '');
    await db.setSetting('lastfm_session_key', '');
    await db.setSetting('lastfm_api_key', '');
    await db.setSetting('lastfm_api_secret', '');
    _authToken = null;
    _authUrl = null;
    _error = null;
    _lastScrobbledAt = null;
    _scrobbleEnabled = true;
    notifyListeners();
  }

  Future<void> setScrobbleEnabled(bool enabled) async {
    _scrobbleEnabled = enabled;
    final db = DatabaseService.instance;
    await db.setSetting('lastfm_scrobble_enabled', enabled.toString());
    notifyListeners();
  }

  Future<void> scrobble({
    required String artist,
    required String track,
    int? timestamp,
    String? album,
  }) async {
    if (!_scrobbleEnabled || _service == null || !_service!.isConnected) return;
    try {
      await _service!.scrobble(
        artist: artist,
        track: track,
        timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        album: album,
      );
      _lastScrobbledAt = DateTime.now();
      final db = DatabaseService.instance;
      await db.setSetting('lastfm_last_scrobbled_at', _lastScrobbledAt!.toIso8601String());
    } catch (e) {
      debugPrint('Scrobble failed: $e');
    }
  }

  Future<void> updateNowPlaying({
    required String artist,
    required String track,
    String? album,
    int? duration,
  }) async {
    if (_service == null || !_service!.isConnected) return;
    try {
      await _service!.updateNowPlaying(
        artist: artist,
        track: track,
        album: album,
        duration: duration,
      );
    } catch (e) {
      debugPrint('NowPlaying update failed: $e');
    }
  }

  Future<LastFmTrackInfo?> getTrackInfo(String artist, String track) async {
    if (_service == null) return null;
    try {
      return await _service!.getTrackInfo(artist, track);
    } catch (e) {
      debugPrint('getTrackInfo failed: $e');
      return null;
    }
  }

  Future<List<LastFmTopTrack>> getTopTracks(String period) async {
    if (_service == null || !_service!.isConnected) return [];
    try {
      return await _service!.getTopTracks(period);
    } catch (e) {
      debugPrint('getTopTracks failed: $e');
      return [];
    }
  }
}
