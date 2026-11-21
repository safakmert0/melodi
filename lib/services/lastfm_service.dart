import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'database_service.dart';
import 'sources/hifi_source.dart';

/// Last.fm scrobbling: Melodi backend proxy üzerinden auth ve scrobble.
///
/// Akış: `/api/lastfm/token` → kullanıcı tarayıcıda onaylar →
/// `/api/lastfm/session` → sessionKey DB'de saklanır → çalma anında
/// `track.updateNowPlaying` + %50 sonrası `track.scrobble`.
class LastfmService {
  static final LastfmService instance = LastfmService._();
  LastfmService._();

  static const String _sessionKeyDb = 'lastfm_session_key';
  static const String _usernameDb = 'lastfm_username';
  static const Duration _timeout = Duration(seconds: 15);

  Future<String> _base() async {
    final saved = await DatabaseService.instance.getSetting('hifi_backend_url');
    if (saved != null && saved.isNotEmpty) return saved;
    return HiFiSource.defaultBaseUrl;
  }

  Future<bool> isServerConfigured() async {
    try {
      final base = await _base();
      if (base.isEmpty) return false;
      final res =
          await http.get(Uri.parse('$base/api/lastfm/config')).timeout(_timeout);
      return res.statusCode == 200 && res.body.contains('"enabled":true');
    } catch (_) {
      return false;
    }
  }

  Future<bool> isConnected() async {
    final key = await DatabaseService.instance.getSetting(_sessionKeyDb);
    return key != null && key.isNotEmpty;
  }

  Future<String> username() async {
    return await DatabaseService.instance.getSetting(_usernameDb) ?? '';
  }

  /// Kullanıcıyı Last.fm onay sayfasına yönlendirmek için token + URL döner.
  Future<({String token, String authUrl})> requestToken() async {
    final base = await _base();
    final res =
        await http.post(Uri.parse('$base/api/lastfm/token')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Last.fm token alınamadı (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      token: body['token'] as String,
      authUrl: body['authUrl'] as String,
    );
  }

  /// Kullanıcı tarayıcıda onayladıktan sonra sessionKey'i saklar.
  Future<String> authenticate(String token) async {
    final base = await _base();
    final res = await http
        .post(
          Uri.parse('$base/api/lastfm/session'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Last.fm oturumu açılamadı (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sessionKey = body['sessionKey'] as String;
    final user = body['username'] as String? ?? '';
    await DatabaseService.instance.setSetting(_sessionKeyDb, sessionKey);
    await DatabaseService.instance.setSetting(_usernameDb, user);
    return user;
  }

  Future<void> disconnect() async {
    await DatabaseService.instance.setSetting(_sessionKeyDb, '');
    await DatabaseService.instance.setSetting(_usernameDb, '');
  }

  Future<void> updateNowPlaying({
    required String artist,
    required String track,
    String album = '',
    int durationMs = 0,
  }) async {
    final key = await _sessionKey();
    if (key == null) return;
    try {
      final base = await _base();
      await http
          .post(
            Uri.parse('$base/api/lastfm/nowplaying'),
            headers: {'Content-Type': 'application/json'},
            body: _payload(key, artist, track, album, durationMs, null),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('Last.fm nowplaying failed: $e');
    }
  }

  Future<void> scrobble({
    required String artist,
    required String track,
    String album = '',
    int durationMs = 0,
    int? timestamp,
  }) async {
    final key = await _sessionKey();
    if (key == null) return;
    try {
      final base = await _base();
      final res = await http
          .post(
            Uri.parse('$base/api/lastfm/scrobble'),
            headers: {'Content-Type': 'application/json'},
            body: _payload(key, artist, track, album, durationMs, timestamp),
          )
          .timeout(_timeout);
      debugPrint('Last.fm scrobble: ${res.statusCode}');
    } catch (e) {
      debugPrint('Last.fm scrobble failed: $e');
    }
  }

  Future<String?> _sessionKey() async {
    final key = await DatabaseService.instance.getSetting(_sessionKeyDb);
    if (key == null || key.isEmpty) return null;
    return key;
  }

  String _payload(
    String key,
    String artist,
    String track,
    String album,
    int durationMs,
    int? timestamp,
  ) {
    final map = <String, dynamic>{
      'sessionKey': key,
      'artist': artist,
      'track': track,
      'album': album,
      'duration': durationMs,
    };
    if (timestamp != null) map['timestamp'] = timestamp;
    return jsonEncode(map);
  }
}
