import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'encryption_service.dart';

class YouTubeCookieAuth {
  static const String _baseUrl = 'https://music.youtube.com';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  String? _cookieString;
  String? _sapiSid;
  String? _authHeader;

  bool get isLoggedIn => _cookieString != null;

  void loginWithCookies(String cookieString) {
    _cookieString = cookieString;
    _sapiSid = _extractSapiSid(cookieString);
    if (_sapiSid != null) {
      _authHeader = _generateAuthHeader(_sapiSid!);
    }
  }

  String? getAuthToken() {
    return _authHeader;
  }

  String? _extractSapiSid(String cookie) {
    for (final name in ['__Secure-3PSAPISID', '__Secure-1PSAPISID', 'SAPISID']) {
      final regex = RegExp('$name=([^;]+)');
      final match = regex.firstMatch(cookie);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String _generateAuthHeader(String sapiSid) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final hash = sha1.convert(utf8.encode('$timestamp $sapiSid')).toString();
    return 'SAPISIDHASH ${timestamp}_$hash';
  }

  Future<bool> validateCookies() async {
    if (_cookieString == null) return false;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.parse('$_baseUrl/youtubei/v1/browse?prettyPrint=false'));
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('User-Agent', _userAgent);
        request.headers.set('X-YouTube-Client-Name', '67');
        request.headers.set('X-YouTube-Client-Version', '1.20250304.00.00');
        request.headers.set('Origin', 'https://music.youtube.com');
        request.headers.set('Referer', 'https://music.youtube.com/');
        if (_authHeader != null) {
          request.headers.set('Authorization', _authHeader!);
          request.headers.set('Cookie', _cookieString!);
          request.headers.set('X-Goog-AuthUser', '0');
        }
        request.write(jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20250304.00.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'browseId': 'FEmusic_home',
        }));
        final response = await request.close();
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('YouTubeCookieAuth.validateCookies failed: $e');
      return false;
    }
  }

  Future<void> storeCookiesEncrypted(String cookies) async {
    final db = DatabaseService.instance;
    final encrypted = EncryptionService.encrypt(cookies);
    await db.setSetting('ytmusic_cookie_enc', encrypted);
  }

  Future<String?> getStoredCookies() async {
    final db = DatabaseService.instance;
    final encrypted = await db.getSetting('ytmusic_cookie_enc');
    if (encrypted == null) return null;
    return EncryptionService.decrypt(encrypted);
  }

  Future<void> logout() async {
    _cookieString = null;
    _sapiSid = null;
    _authHeader = null;
    final db = DatabaseService.instance;
    await db.setSetting('ytmusic_cookie_enc', '');
  }
}
