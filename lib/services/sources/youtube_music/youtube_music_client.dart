import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// YouTubeMusicClient — Handles IOS_MUSIC client context
/// Auto-updates User-Agent and client version based on app version
class YouTubeMusicClient {
  static final YouTubeMusicClient _instance = YouTubeMusicClient._internal();
  factory YouTubeMusicClient() => _instance;
  YouTubeMusicClient._internal();

  // Constants
  static const String _baseClientName = 'IOS_MUSIC';
  static const String _baseClientVersion = '5.26.1';
  static const String _apiKey = 'AIzaSyBAETezhkwP0ZWA02RsqT1zu78Fpt0bC_s';
  static const String _baseUrl = 'https://www.youtube.com/youtubei/v1';

  // Dynamic values
  String _clientVersion = _baseClientVersion;
  String _osVersion = '17.0';
  String _deviceModel = 'iPhone15,2';
  String _appVersion = '1.0.0';
  String _buildNumber = '1';

  // Getters
  String get clientName => 'IOS_MUSIC';
  String get clientVersion => _clientVersion;
  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  String get userAgent => _buildUserAgent();
  String get osVersion => _osVersion;
  String get deviceModel => _deviceModel;
  String get appVersion => _appVersion;
  String get buildNumber => _buildNumber;

  /// Initialize client with app info
  Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;

      // Update client version based on app version
      // Format: 5.XX.Y where XX = major.minor, Y = patch
      final versionParts = _appVersion.split('.');
      if (versionParts.length >= 2) {
        _clientVersion = '5.${versionParts[0]}.${versionParts[1]}';
      }

      // Detect iOS version
      if (Platform.isIOS) {
        _osVersion = await _getIOSVersion() ?? '17.0';
        _deviceModel = await _getDeviceModel() ?? 'iPhone15,2';
      }

      debugPrint('YouTubeMusicClient initialized: v$_clientVersion, iOS $_osVersion, $_deviceModel');
    } catch (e) {
      debugPrint('YouTubeMusicClient init error: $e');
    }
  }

  /// Build User-Agent string matching official IOS_MUSIC client
  String _buildUserAgent() {
    return 'com.google.ios.youtube.music/$_clientVersion '
        '($_deviceModel; U; CPU iOS ${_osVersion.replaceAll('.', '_')} like Mac OS X)';
  }

  /// Get iOS version (requires native plugin or fallback)
  Future<String?> _getIOSVersion() async {
    // In production, use device_info_plus plugin
    // For now, return reasonable default
    return '17.0';
  }

  /// Get device model (requires native plugin or fallback)
  Future<String?> _getDeviceModel() async {
    // In production, use device_info_plus plugin
    // For now, return reasonable default
    return 'iPhone15,2';
  }

  /// Build client context for API requests
  Map<String, dynamic> get clientContext => {
        'client': {
          'clientName': clientName,
          'clientVersion': _clientVersion,
          'hl': 'en',
          'gl': 'US',
          'osName': 'iOS',
          'osVersion': _osVersion,
          'deviceMake': 'Apple',
          'deviceModel': _deviceModel,
          'userAgent': userAgent,
          'clientScreen': 'MUSIC_PLAYBACK',
        },
      };

  /// Build request body with client context
  Map<String, dynamic> buildRequestBody(Map<String, dynamic> payload) {
    return {
      ...clientContext,
      ...payload,
    };
  }

  /// HTTP headers for requests
  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'User-Agent': userAgent,
        'X-Goog-Api-Key': 'AIzaSyBAETezhkwP0ZWA02RsqT1zu78Fpt0bC_s',
        'X-Goog-AuthUser': '0',
      };

  /// Update client version (e.g., when app updates)
  void updateClientVersion(String version) {
    _clientVersion = version;
  }

  /// Update iOS version
  void updateOSVersion(String version) {
    _osVersion = version;
  }

  /// Update device model
  void updateDeviceModel(String model) {
    _deviceModel = model;
  }
}

/// Singleton instance
final youtubeMusicClient = YouTubeMusicClient();