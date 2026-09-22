import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'database_service.dart';
import 'sources/hifi_source.dart';

/// Takip edilen kanallar: backend `/api/follows` uclari.
/// Yeni yuklemeler sunucuda job kuyruguna duser, kütüphaneye katar.
class FollowedChannel {
  const FollowedChannel({
    required this.id,
    required this.url,
    required this.preset,
    required this.writeLyrics,
    required this.embedLyrics,
    required this.maxItems,
    required this.active,
    this.tracked = 0,
  });

  final String id;
  final String url;
  final String preset;
  final bool writeLyrics;
  final bool embedLyrics;
  final int maxItems;
  final bool active;
  final int tracked;

  static const List<String> presets = ['fast', 'quality', 'compact', 'music_only'];
}

class FollowsService {
  FollowsService._();
  static final FollowsService instance = FollowsService._();

  static const Duration _timeout = Duration(seconds: 30);
  static const String _tokenKey = 'melodi_api_token';

  Future<String> baseUrl() => HiFiSource().baseUrl();

  Future<String?> apiToken() async {
    try {
      final v = await DatabaseService.instance.getSetting(_tokenKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  Future<void> setApiToken(String token) async {
    await DatabaseService.instance
        .setSetting(_tokenKey, token.trim());
  }

  Future<Map<String, String>> _headers() async {
    final h = {'Content-Type': 'application/json'};
    final token = await apiToken();
    if (token != null && token.isNotEmpty) {
      h['X-API-Token'] = token;
    }
    return h;
  }

  Future<List<FollowedChannel>> list() async {
    try {
      final base = await baseUrl();
      final response = await http
          .get(Uri.parse('$base/api/follows'))
          .timeout(_timeout);
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracked =
          (data['tracked'] as Map?)?.map((k, v) => MapEntry('$k', v)) ?? {};
      return ((data['follows'] as List?) ?? const [])
          .whereType<Map>()
          .map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            final id = '${m['id'] ?? ''}';
            return FollowedChannel(
              id: id,
              url: '${m['url'] ?? ''}',
              preset: '${m['preset'] ?? 'music_only'}',
              writeLyrics: m['write_lyrics'] == true,
              embedLyrics: m['embed_lyrics'] == true,
              maxItems: (m['max_items'] as num?)?.toInt() ?? 3,
              active: m['active'] != false,
              tracked: (tracked[id] as num?)?.toInt() ?? 0,
            );
          })
          .where((f) => f.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Follows list error: $e');
      return const [];
    }
  }

  /// (id, hata). Hata 'yetkisiz' ise API anahtarı gerekir.
  Future<(String?, String?)> add({
    required String url,
    String preset = 'music_only',
    bool writeLyrics = false,
    bool embedLyrics = false,
    int maxItems = 3,
  }) async {
    try {
      final base = await baseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/follows'),
            headers: await _headers(),
            body: jsonEncode({
              'url': url.trim(),
              'preset': preset,
              'write_lyrics': writeLyrics,
              'embed_lyrics': embedLyrics,
              'max_items': maxItems,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 401) return (null, 'yetkisiz');
      if (response.statusCode != 200) return (null, 'HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ('${data['id'] ?? ''}', null);
    } catch (e) {
      debugPrint('Follows add error: $e');
      return (null, '$e');
    }
  }

  Future<bool> remove(String id) async {
    try {
      final base = await baseUrl();
      final response = await http
          .delete(Uri.parse('$base/api/follows/$id'),
              headers: await _headers())
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Follows remove error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkNow() async {
    try {
      final base = await baseUrl();
      final response = await http
          .post(Uri.parse('$base/api/follows/check'),
              headers: await _headers())
          .timeout(const Duration(minutes: 5));
      if (response.statusCode == 401) return {'error': 'yetkisiz'};
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Follows check error: $e');
      return null;
    }
  }
}
