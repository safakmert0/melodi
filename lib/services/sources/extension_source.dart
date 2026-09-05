import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/extension.dart';
import '../js_extension_service.dart';
import '../music_source.dart';
import 'jiosaavn_source.dart';
import 'soundcloud_source.dart';

/// Her kurulu eklentiyi ayrı MusicSource olarak sarmalar.
/// SpotiFLAC (.sflx) için JS sandbox (A), 8spine (.8spine/.js) için native Dart (B) + fallback bridge.
class ExtensionMusicSource implements MusicSource {
  ExtensionMusicSource(this.extension);

  final InstalledExtension extension;
  String get id => extension.manifest.id;
  String get bundleUrl => extension.manifest.homepage ?? '';

  // Heuristic: JS bundle mı?
  bool get isJsBundle {
    final url = bundleUrl.toLowerCase();
    return url.endsWith('.sflx') ||
        url.endsWith('.spotiflac-ext') ||
        url.endsWith('.8spine') ||
        url.endsWith('.js') ||
        extension.manifest.id.contains('spotify') ||
        extension.manifest.id.contains('tidal');
  }

  @override
  MusicSourceType get type {
    // Eklentinin kind'ine göre map et, ama arama filtrelerinde ayrı görünsün diye extensionName kullanacağız
    if (extension.manifest.kind == ExtensionKind.hifi)
      return MusicSourceType.hifi;
    return MusicSourceType.youtube;
  }

  @override
  String get name => extension.manifest.name;

  // Eklentiye özel baseUrl (bridge fallback)
  String get baseUrl => extension.manifest.baseUrl;

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final lowerId = id.toLowerCase();
    final lowerName = name.toLowerCase();

    // 8spine native özel: bilinen sağlayıcıları doğrudan native API'ye yönlendir (B)
    if (lowerId.contains('jiosaavn') || lowerName.contains('jiosaavn')) {
      try {
        final src = _getNativeSource(MusicSourceType.jiosaavn);
        if (src != null) {
          final res = await src.search(trimmed, limit: limit);
          return res
              .map((t) => t.copyWith(extensionId: id, extensionName: name))
              .toList();
        }
      } catch (_) {}
    }
    if (lowerId.contains('soundcloud') || lowerName.contains('soundcloud')) {
      try {
        final src = _getNativeSource(MusicSourceType.soundcloud);
        if (src != null) {
          final res = await src.search(trimmed, limit: limit);
          return res
              .map((t) => t.copyWith(extensionId: id, extensionName: name))
              .toList();
        }
      } catch (_) {}
    }

    // 1) JS bundle ise önce JS dene (SpotiFLAC A)
    if (isJsBundle) {
      try {
        final entry = RegistryEntry(
          id: extension.manifest.id,
          name: extension.manifest.name,
          url: bundleUrl.isNotEmpty ? bundleUrl : extension.manifest.baseUrl,
          version: extension.manifest.version,
          description: extension.manifest.description,
          kind: extension.manifest.kind,
          author: extension.manifest.author,
          permissions: extension.manifest.permissions,
        );
        final jsResults = await JsExtensionService.instance
            .search(entry, trimmed, limit: limit);
        if (jsResults.isNotEmpty) {
          return jsResults
              .map((m) => _mapToTrack(m, limit))
              .whereType<OnlineTrack>()
              .toList();
        }
      } catch (e) {
        debugPrint('Extension JS search failed (${extension.manifest.id}): $e');
      }
    }

    // 2) Native/Dart fallback: baseUrl üzerinden backend API (B)
    try {
      final url = extension.manifest.kind == ExtensionKind.hifi
          ? '$baseUrl/api/hifi/search'
          : '$baseUrl/api/search';
      final body = jsonEncode({'query': trimmed, 'limit': limit});
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Melodi/1.0'
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tracks =
          (data['tracks'] as List? ?? data['results'] as List? ?? const [])
              .whereType<Map>()
              .map((m) => _mapGenericToTrack(Map<String, dynamic>.from(m)))
              .whereType<OnlineTrack>()
              .toList();
      return tracks.take(limit).toList();
    } catch (e) {
      debugPrint(
          'Extension native search failed (${extension.manifest.id}): $e');
      return [];
    }
  }

  OnlineTrack? _mapToTrack(Map<String, dynamic> m, int limit) {
    try {
      return OnlineTrack(
        id: (m['id'] ?? m['videoId'] ?? m['trackId'] ?? '').toString(),
        title: (m['title'] ?? m['name'] ?? 'Unknown').toString(),
        artist: _artistText(
            m['artist'] ?? m['artists'] ?? m['author'] ?? m['uploader']),
        album: (m['album'] ?? m['album_name'])?.toString(),
        duration: Duration(milliseconds: _durationMs(m)),
        thumbnailUrl: m['thumbnail']?.toString() ??
            m['artwork']?.toString() ??
            m['cover_url']?.toString(),
        source: type,
        extensionId: extension.manifest.id,
        extensionName: extension.manifest.name,
      );
    } catch (_) {
      return null;
    }
  }

  String _artistText(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item is Map ? item['name'] : item)
          .where((item) => item != null)
          .join(', ');
    }
    return value?.toString() ?? 'Unknown';
  }

  int _durationMs(Map<String, dynamic> value) {
    final millis = value['duration_ms'] ?? value['durationMs'];
    if (millis != null)
      return (millis as num?)?.round() ?? int.tryParse('$millis') ?? 0;
    final seconds = value['duration'];
    return ((seconds as num?)?.toDouble() ?? double.tryParse('$seconds') ?? 0) *
        1000 ~/
        1;
  }

  OnlineTrack? _mapGenericToTrack(Map<String, dynamic> m) {
    try {
      final id = (m['id'] ?? m['spotify_url'] ?? m['videoId'] ?? '').toString();
      if (id.isEmpty) return null;
      return OnlineTrack(
        id: id,
        title: (m['title'] ?? m['name'] ?? 'Unknown').toString(),
        artist: (m['artist'] ?? m['author'] ?? 'Unknown').toString(),
        album: m['album']?.toString(),
        duration: Duration(
            seconds: int.tryParse(m['duration']?.toString() ?? '0') ?? 0),
        thumbnailUrl:
            m['thumbnail']?.toString() ?? m['thumbnailUrl']?.toString(),
        source: type,
        extensionId: extension.manifest.id,
        extensionName: extension.manifest.name,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    // Eğer track bu eklentiden geldiyse, o eklentinin yöntemiyle stream al
    if (track.extensionId != null && track.extensionId != extension.manifest.id)
      return null;

    // 1) JS
    if (isJsBundle) {
      try {
        final entry = RegistryEntry(
          id: extension.manifest.id,
          name: extension.manifest.name,
          url: bundleUrl.isNotEmpty ? bundleUrl : extension.manifest.baseUrl,
          version: extension.manifest.version,
          description: extension.manifest.description,
          kind: extension.manifest.kind,
          author: extension.manifest.author,
          permissions: extension.manifest.permissions,
        );
        final url =
            await JsExtensionService.instance.getStreamUrl(entry, track.id);
        if (url != null && url.isNotEmpty) return url;
        final providerUrl = await JsExtensionService.instance.getProviderUrl(
          entry,
          {
            'id': track.id,
            'title': track.title,
            'artist': track.artist,
            'album': track.album,
            'durationMs': track.duration.inMilliseconds,
          },
        );
        if (providerUrl != null && providerUrl.isNotEmpty) return providerUrl;
      } catch (e) {
        debugPrint('Extension JS getStreamUrl failed: $e');
      }
    }

    // 2) Native backend
    try {
      final apiUrl = extension.manifest.kind == ExtensionKind.hifi
          ? '$baseUrl/api/hifi/stream/${track.id}'
          : '$baseUrl/api/stream/${track.id}';
      // For hifi, try GET stream, else return baseUrl stream
      if (extension.manifest.kind == ExtensionKind.hifi) {
        final resp = await http.get(Uri.parse(apiUrl), headers: {
          'User-Agent': 'Melodi/1.0'
        }).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final url = data['url']?.toString() ?? data['streamUrl']?.toString();
          if (url != null && url.isNotEmpty) return url;
        }
      }
      return '$baseUrl/api/stream/${track.id}';
    } catch (_) {
      return null;
    }
  }

  MusicSource? _getNativeSource(MusicSourceType t) {
    switch (t) {
      case MusicSourceType.jiosaavn:
        return JioSaavnSource();
      case MusicSourceType.soundcloud:
        return SoundCloudSource();
      default:
        return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
