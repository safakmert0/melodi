import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database_service.dart';
import '../music_source.dart';
import 'hifi_source.dart';

/// Soulseek kaynağı: Docker'daki slskd üzerinden arama, indirme ve akış.
///
/// Akış: backend `/api/slskd/search` → seçilen parça
/// `/api/slskd/download` ile slskd kuyruğuna alınır → transfer bitince
/// backend `/api/slskd/download/.../file` dosyayı akıtır.
class SlskdSource implements MusicSource {
  static const Duration _timeout = Duration(seconds: 25);

  @override
  MusicSourceType get type => MusicSourceType.slskd;

  @override
  String get name => 'Soulseek';

  Future<String> _base() async {
    final saved =
        await DatabaseService.instance.getSetting('hifi_backend_url');
    if (saved != null && saved.isNotEmpty) return saved;
    return HiFiSource.defaultBaseUrl;
  }

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final base = await _base();
      if (base.isEmpty) return const [];
      final uri = Uri.parse('$base/api/slskd/search')
          .replace(queryParameters: {'query': trimmed, 'limit': '$limit'});
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List?) ?? const [];
      return results
          .whereType<Map>()
          .map((r) => _toTrack(Map<String, dynamic>.from(r)))
          .whereType<OnlineTrack>()
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('slskd search failed: $e');
      return const [];
    }
  }

  OnlineTrack? _toTrack(Map<String, dynamic> r) {
    final username = r['username'] as String? ?? '';
    final filename = r['filename'] as String? ?? '';
    if (username.isEmpty || filename.isEmpty) return null;
    final baseName = filename.split('/').last.replaceAll(
        RegExp(r'\.(mp3|flac|m4a|ogg|wav|aac|opus)$', caseSensitive: false),
        '');
    final parts = baseName.split(' - ');
    final artist = parts.length > 1 ? parts[0].trim() : 'Bilinmeyen';
    final title = parts.length > 1
        ? parts.sublist(1).join(' - ').trim()
        : baseName;
    final sizeBytes = (r['size'] as num?)?.toInt() ?? 0;
    final bitrate = (r['bitrate'] as num?)?.toInt() ?? 0;
    Duration duration = Duration.zero;
    if (sizeBytes > 0 && bitrate > 0) {
      final seconds = ((sizeBytes * 8) / (bitrate * 1000)).round();
      duration = Duration(seconds: seconds);
    }
    return OnlineTrack(
      id: 'slskd://$username/${Uri.encodeComponent(filename)}',
      title: title,
      artist: artist,
      duration: duration,
      source: MusicSourceType.slskd,
      streamUrl: 'slskd://$username/${Uri.encodeComponent(filename)}',
      itemType: 'song',
    );
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    try {
      final id = track.streamUrl ?? track.id;
      if (!id.startsWith('slskd://')) return null;
      final rest = id.substring('slskd://'.length);
      final slash = rest.indexOf('/');
      if (slash < 0) return null;
      final username = rest.substring(0, slash);
      final filename = Uri.decodeComponent(rest.substring(slash + 1));

      final base = await _base();
      if (base.isEmpty) return null;

      // 1) Kuyruğa ekle
      await http
          .post(
            Uri.parse('$base/api/slskd/download'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'filename': filename}),
          )
          .timeout(_timeout);

      // 2) Transfer durumunu bekle (en fazla ~90 sn)
      final statusUri =
          Uri.parse('$base/api/slskd/download/$username/status')
              .replace(queryParameters: {'filename': filename});
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));
        final res =
            await http.get(statusUri).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final state = (body['state'] as String?) ?? '';
          if (state == 'Completed' || state == 'Succeeded') {
            final fileUri =
                Uri.parse('$base/api/slskd/download/$username/file')
                    .replace(queryParameters: {'filename': filename});
            return fileUri.toString();
          }
          if (state == 'Faulted' || state == 'Cancelled') return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('slskd stream failed: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
