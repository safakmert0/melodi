import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class LastFmSession {
  final String username;
  final String sessionKey;

  const LastFmSession({required this.username, required this.sessionKey});
}

class LastFmTrackInfo {
  final String? mbid;
  final int? durationMs;
  final int listeners;
  final int playcount;
  final String? bestImageUrl;

  const LastFmTrackInfo({
    this.mbid,
    this.durationMs,
    this.listeners = 0,
    this.playcount = 0,
    this.bestImageUrl,
  });
}

class LastFmService {
  static const _apiUrl = 'https://ws.audioscrobbler.com/2.0/';

  final String apiKey;
  final String apiSecret;

  LastFmSession? _session;

  LastFmService({required this.apiKey, required this.apiSecret});

  bool get isConnected => _session != null;
  LastFmSession? get session => _session;

  void setSession(LastFmSession? session) {
    _session = session;
  }

  String _sign(Map<String, String> params) {
    final sorted = List<String>.from(params.keys)..sort();
    final base = StringBuffer();
    for (final key in sorted) {
      base.write(key);
      base.write(params[key]);
    }
    base.write(apiSecret);
    return md5.convert(utf8.encode(base.toString())).toString();
  }

  Future<Map<String, dynamic>> _signedGet(Map<String, String> params) async {
    final fullParams = Map<String, String>.from(params);
    fullParams['api_sig'] = _sign(fullParams);
    fullParams['format'] = 'json';
    return _request(fullParams);
  }

  Future<Map<String, dynamic>> _signedPost(Map<String, String> params) async {
    final fullParams = Map<String, String>.from(params);
    fullParams['api_sig'] = _sign(fullParams);
    fullParams['format'] = 'json';
    return _post(fullParams);
  }

  Future<Map<String, dynamic>> _unsignedGet(
      Map<String, String> params) async {
    final fullParams = Map<String, String>.from(params);
    fullParams['format'] = 'json';
    return _request(fullParams);
  }

  Future<Map<String, dynamic>> _request(Map<String, String> params) async {
    final uri = Uri.parse(_apiUrl).replace(queryParameters: params);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/1.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw LastFmException(
            data['message'] as String? ?? 'Unknown error',
            data['error'] as int? ?? 0);
      }
      return data;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, String> params) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(Uri.parse(_apiUrl));
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      request.headers.set('User-Agent', 'Melodi/1.0');
      request.write(params.entries.map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw LastFmException(
            data['message'] as String? ?? 'Unknown error',
            data['error'] as int? ?? 0);
      }
      return data;
    } finally {
      client.close();
    }
  }

  Future<String> getAuthToken() async {
    final params = {
      'method': 'auth.getToken',
      'api_key': apiKey,
    };
    final response = await _signedGet(params);
    return response['token'] as String;
  }

  String getAuthUrl(String token) {
    return 'https://www.last.fm/api/auth/?api_key=$apiKey&token=$token';
  }

  Future<LastFmSession> getSession(String token) async {
    final params = {
      'method': 'auth.getSession',
      'api_key': apiKey,
      'token': token,
    };
    final response = await _signedGet(params);
    final session = response['session'] as Map<String, dynamic>;
    return LastFmSession(
      username: session['name'] as String,
      sessionKey: session['key'] as String,
    );
  }

  Future<void> scrobble({
    required String artist,
    required String track,
    required int timestamp,
    String? album,
  }) async {
    if (_session == null) throw LastFmException('Not connected', 0);
    final params = {
      'method': 'track.scrobble',
      'api_key': apiKey,
      'sk': _session!.sessionKey,
      'artist': artist,
      'track': track,
      'timestamp': timestamp.toString(),
    };
    if (album != null && album.isNotEmpty) params['album'] = album;
    await _signedPost(params);
  }

  Future<void> updateNowPlaying({
    required String artist,
    required String track,
    String? album,
  }) async {
    if (_session == null) return;
    final params = {
      'method': 'track.updateNowPlaying',
      'api_key': apiKey,
      'sk': _session!.sessionKey,
      'artist': artist,
      'track': track,
    };
    if (album != null && album.isNotEmpty) params['album'] = album;
    await _signedPost(params);
  }
}

class LastFmException implements Exception {
  final String message;
  final int code;
  const LastFmException(this.message, this.code);
  @override
  String toString() => 'LastFmException($code): $message';
}
