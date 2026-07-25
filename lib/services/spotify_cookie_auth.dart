import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'encryption_service.dart';
import 'secure_storage_service.dart';

class SpotifyCookieAuth {
  static const _spDcKey = 'spotify_sp_dc';
  static const _spKeyKey = 'spotify_sp_key';
  static const _legacySpDcKey = 'spotify_sp_dc_enc';
  static const _legacySpKeyKey = 'spotify_sp_key_enc';

  static const String _tokenUrl = 'https://open.spotify.com/get_access_token';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36';

  String? _spDc;
  String? _spKey;
  String? _accessToken;
  int _expiresAtEpoch = 0;

  bool get isLoggedIn => _spDc != null;
  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 >= _expiresAtEpoch;

  Future<bool> loginWithCookies(String spDc, String spKey) async {
    try {
      final token = await _exchangeToken(spDc, spKey);
      if (token == null) return false;
      _spDc = spDc;
      _spKey = spKey;
      _accessToken = token;
      return true;
    } catch (e) {
      debugPrint('SpotifyCookieAuth.loginWithCookies failed: $e');
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    if (_accessToken != null && !isExpired) return _accessToken;
    if (_spDc == null) return null;
    final token = await _exchangeToken(_spDc!, _spKey);
    if (token != null) _accessToken = token;
    return token;
  }

  Future<bool> refreshToken() async {
    if (_spDc == null) return false;
    final token = await _exchangeToken(_spDc!, _spKey);
    if (token == null) return false;
    _accessToken = token;
    return true;
  }

  Future<bool> validateCookies() async {
    try {
      final token = await getAccessToken();
      if (token == null) return false;
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyCookieAuth.validateCookies failed: $e');
      return false;
    }
  }

  Future<String?> _exchangeToken(String spDc, String? spKey) async {
    try {
      final headers = <String, String>{
        'Cookie': 'sp_dc=$spDc',
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        'App-Platform': 'WebPlayer',
        'Referer': 'https://open.spotify.com/',
      };
      if (spKey != null && spKey.isNotEmpty) {
        headers['Cookie'] = 'sp_dc=$spDc; sp_key=$spKey';
      }

      final response = await http.get(
        Uri.parse('$_tokenUrl?reason=transport&productType=web-player'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
            'Spotify token exchange failed: HTTP ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final isAnonymous = body['isAnonymous'] as bool? ?? true;
      if (isAnonymous) return null;

      final accessToken = body['accessToken'] as String?;
      final expiresMs = body['accessTokenExpirationTimestampMs'] as int? ?? 0;
      if (accessToken == null) return null;

      _accessToken = accessToken;
      _expiresAtEpoch = expiresMs ~/ 1000;
      return accessToken;
    } catch (e) {
      debugPrint('SpotifyCookieAuth._exchangeToken failed: $e');
      return null;
    }
  }

  Future<void> storeCookiesEncrypted(String spDc, String spKey) async {
    final secureStorage = SecureStorageService.instance;
    await secureStorage.write(_spDcKey, spDc);
    await secureStorage.write(_spKeyKey, spKey);
    final db = DatabaseService.instance;
    await db.deleteSetting(_legacySpDcKey);
    await db.deleteSetting(_legacySpKeyKey);
  }

  Future<Map<String, String?>> getStoredCookies() async {
    final secureStorage = SecureStorageService.instance;
    var spDc = await secureStorage.read(_spDcKey);
    var spKey = await secureStorage.read(_spKeyKey);
    if (spDc != null) return {'sp_dc': spDc, 'sp_key': spKey};

    // Migrate credentials written by older releases.
    final db = DatabaseService.instance;
    final encryptedDc = await db.getSetting(_legacySpDcKey);
    final encryptedKey = await db.getSetting(_legacySpKeyKey);
    if (encryptedDc == null) return {'sp_dc': null, 'sp_key': null};
    spDc = EncryptionService.decrypt(encryptedDc);
    spKey =
        encryptedKey != null ? EncryptionService.decrypt(encryptedKey) : null;
    await secureStorage.write(_spDcKey, spDc);
    if (spKey != null) await secureStorage.write(_spKeyKey, spKey);
    await db.deleteSetting(_legacySpDcKey);
    await db.deleteSetting(_legacySpKeyKey);
    return {'sp_dc': spDc, 'sp_key': spKey};
  }

  Future<void> logout() async {
    _spDc = null;
    _spKey = null;
    _accessToken = null;
    _expiresAtEpoch = 0;
    await SecureStorageService.instance.delete(_spDcKey);
    await SecureStorageService.instance.delete(_spKeyKey);
    final db = DatabaseService.instance;
    await db.deleteSetting(_legacySpDcKey);
    await db.deleteSetting(_legacySpKeyKey);
  }
}
