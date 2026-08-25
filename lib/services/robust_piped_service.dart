import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'music_source.dart';

class RobustPipedService {
  RobustPipedService._();
  static final RobustPipedService _instance = RobustPipedService._();
  factory RobustPipedService() => _instance;
  static RobustPipedService get instance => _instance;

  // Resmi + güvenilir Piped instance'ları (2024 aktif)
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://piped-api.jaydp.xyz', 
    'https://piped.mha.fi',
    'https://piped.privacydev.net',
    'https://piped.tilder.org',
    'https://piped.lunar.icu',
    'https://piped.kavin.rocks',
  ];

  // Invidious fallback instance'ları
  static const List<String> _invidiousInstances = [
    'https://yewtu.be',
    'https://invidious.snopyta.org',
    'https://invidious.fdn.fr',
    'https://invidious.nerdvpn.de',
  ];

  final Map<String, InstanceHealth> _health = {};
  Timer? _healthCheckTimer;
  String? _currentInstance;
  final StreamController<String> _instanceChangeController = StreamController.broadcast();

  Stream<String> get instanceChanges => _instanceChangeController.stream;

  Future<void> initialize() async {
    await _loadHealth();
    await _selectBestInstance();
    _startHealthChecks();
  }

  Future<void> _loadHealth() async {
    final prefs = await SharedPreferences.getInstance();
    final allInstances = [..._pipedInstances, ..._invidiousInstances];
    for (final instance in allInstances) {
      final key = 'piped_health_$instance';
      final data = prefs.getString(key);
      if (data != null) {
        _health[instance] = InstanceHealth.fromJson(jsonDecode(data));
      }
    }
  }

  Future<void> _saveHealth() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _health.entries) {
      await prefs.setString('piped_health_${entry.key}', jsonEncode(entry.value.toJson()));
    }
  }

  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 3), (_) => _checkAllInstances());
    _checkAllInstances();
  }

  Future<void> _checkAllInstances() async {
    final allInstances = [..._pipedInstances, ..._invidiousInstances];
    await Future.wait(allInstances.map(_checkInstance));
    await _selectBestInstance();
    await _saveHealth();
  }

  Future<void> _checkInstance(String baseUrl) async {
    final stopwatch = Stopwatch()..start();
    try {
      // Piped health endpoint
      final healthUrl = baseUrl.contains('invidious') 
          ? '$baseUrl/api/v1/comments/test'
          : '$baseUrl/health';
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      final latency = stopwatch.elapsedMilliseconds;
      final healthy = response.statusCode == 200;
      
      _health[baseUrl] = InstanceHealth(
        lastCheck: DateTime.now(),
        latencyMs: latency,
        consecutiveFailures: healthy ? 0 : (_health[baseUrl]?.consecutiveFailures ?? 0) + 1,
        totalRequests: (_health[baseUrl]?.totalRequests ?? 0) + 1,
        successfulRequests: (_health[baseUrl]?.successfulRequests ?? 0) + (healthy ? 1 : 0),
      );
    } catch (_) {
      _health[baseUrl] = InstanceHealth(
        lastCheck: DateTime.now(),
        latencyMs: 9999,
        consecutiveFailures: (_health[baseUrl]?.consecutiveFailures ?? 0) + 1,
        totalRequests: (_health[baseUrl]?.totalRequests ?? 0) + 1,
        successfulRequests: _health[baseUrl]?.successfulRequests ?? 0,
      );
    }
  }

  Future<void> _selectBestInstance() async {
    final candidates = _health.entries
        .where((e) => e.value.consecutiveFailures < 3)
        .toList()
      ..sort((a, b) {
        final aPiped = _pipedInstances.contains(a.key) ? 0 : 1;
        final bPiped = _pipedInstances.contains(b.key) ? 0 : 1;
        if (aPiped != bPiped) return aPiped.compareTo(bPiped);
        return a.value.latencyMs.compareTo(b.value.latencyMs);
      });

    final best = candidates.isNotEmpty ? candidates.first.key : _pipedInstances.first;
    
    if (_currentInstance != best) {
      _currentInstance = best;
      _instanceChangeController.add(best);
      debugPrint('🎵 Piped instance: $best (${_health[best]?.latencyMs}ms)');
    }
  }

  String get currentInstance => _currentInstance ?? _pipedInstances.first;

  // ARAMA - Otomatik fallback ile
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final instances = _getHealthyInstances();
    
    for (final base in instances) {
      try {
        final response = await http.get(
          Uri.parse('$base/${base.contains('invidious') ? 'api/v1/search' : 'api/v1/search'}').replace(queryParameters: {
            'q': query,
            'filter': 'videos',
            if (base.contains('invidious')) 'type': 'video',
          }),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = _extractItems(data, base);
          if (items != null && items.isNotEmpty) {
            _recordSuccess(base);
            return _parseResults(items, limit) ?? [];
          }
        }
        _recordFailure(base);
      } catch (e) {
        debugPrint('Piped search failed ($base): $e');
        _recordFailure(base);
      }
    }
    return [];
  }

  // STREAM URL - Proxy ile (IP gizleme)
  Future<String?> getStreamUrl(String videoId) async {
    final instances = _getHealthyInstances();

    for (final base in instances) {
      try {
        final streamsUrl = base.contains('invidious')
            ? '$base/api/v1/streams/$videoId'
            : '$base/api/v1/streams/$videoId';
        final response = await http.get(
          Uri.parse(streamsUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final streams = _extractStreams(data, base);
          if (streams != null && streams.isNotEmpty) {
            _recordSuccess(base);
            return _selectBestAudioStream(streams, base);
          }
        }
        _recordFailure(base);
      } catch (e) {
        debugPrint('Piped stream failed ($base): $e');
        _recordFailure(base);
      }
    }
    return null;
  }

  // VİDEO BİLGİSİ (süre, thumbnail, vb.)
  Future<VideoInfo?> getVideoInfo(String videoId) async {
    final instances = _getHealthyInstances();

    for (final base in instances) {
      try {
        final infoUrl = base.contains('invidious')
            ? '$base/api/v1/videos/$videoId'
            : '$base/api/v1/videos/$videoId';
        final response = await http.get(
          Uri.parse(infoUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _recordSuccess(base);
          return _parseVideoInfo(data, base);
        }
        _recordFailure(base);
      } catch (_) {
        _recordFailure(base);
      }
    }
    return null;
  }

  List<String> _getHealthyInstances() {
    final all = [..._pipedInstances, ..._invidiousInstances];
    return all.where((i) => (_health[i]?.consecutiveFailures ?? 0) < 3).toList()
      ..sort((a, b) {
        final aPiped = _pipedInstances.contains(a) ? 0 : 1;
        final bPiped = _pipedInstances.contains(b) ? 0 : 1;
        if (aPiped != bPiped) return aPiped.compareTo(bPiped);
        return (_health[a]?.latencyMs ?? 9999).compareTo(_health[b]?.latencyMs ?? 9999);
      });
  }

  void _recordSuccess(String base) {
    final h = _health[base];
    if (h != null) {
      _health[base] = InstanceHealth(
        lastCheck: h.lastCheck,
        latencyMs: h.latencyMs,
        consecutiveFailures: 0,
        totalRequests: h.totalRequests + 1,
        successfulRequests: h.successfulRequests + 1,
      );
    }
  }

  void _recordFailure(String base) {
    final h = _health[base];
    if (h != null) {
      _health[base] = InstanceHealth(
        lastCheck: h.lastCheck,
        latencyMs: 9999,
        consecutiveFailures: h.consecutiveFailures + 1,
        totalRequests: h.totalRequests + 1,
        successfulRequests: h.successfulRequests,
      );
    }
    if ((h?.consecutiveFailures ?? 0) >= 2) {
      _selectBestInstance();
    }
  }

  dynamic _extractItems(dynamic data, String base) {
    if (base.contains('invidious')) {
      return data is List ? data : data['items'];
    }
    return data['items'];
  }

  dynamic _extractStreams(dynamic data, String base) {
    if (base.contains('invidious')) {
      return data['adaptiveFormats'] ?? data['formatStreams'];
    }
    return data['audioStreams'];
  }

  List<OnlineTrack>? _parseResults(dynamic items, int limit) {
    if (items is! List) return null;
    return items
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map((item) {
          final url = item['url']?.toString() ?? '';
          final videoId = _extractVideoId(url);
          if (videoId == null) return null;
          return OnlineTrack(
            id: videoId,
            title: item['title']?.toString() ?? 'Bilinmeyen',
            artist: item['uploaderName']?.toString() ?? item['author']?.toString() ?? 'Bilinmeyen',
            duration: Duration(seconds: (item['duration'] as num?)?.toInt() ?? 0),
            thumbnailUrl: item['thumbnail']?.toString() ?? item['videoThumbnails']?.last['url']?.toString(),
            source: MusicSourceType.youtube,
          );
        })
        .whereType<OnlineTrack>()
        .toList();
  }

  String? _selectBestAudioStream(dynamic streams, String base) {
    final list = streams is List ? streams : [];
    if (list.isEmpty) return null;

    Map<dynamic, dynamic>? best;
    int bestBitrate = -1;
    bool bestProxied = false;

    for (final s in list) {
      if (s is! Map) continue;
      final mime = s['mimeType']?.toString() ?? '';
      if (!mime.contains('mp4') && !mime.contains('webm') && !mime.contains('opus')) continue;
      final url = s['url']?.toString() ?? '';
      if (url.isEmpty) continue;
      final bitrate = (s['bitrate'] as num?)?.toInt() ?? 0;
      final proxied = url.contains('/proxy') || url.contains('proxy.') || url.contains('/api/v1/stream/');
      
      if (best == null || (proxied && !bestProxied) || (proxied == bestProxied && bitrate > bestBitrate)) {
        best = s;
        bestBitrate = bitrate;
        bestProxied = proxied;
      }
    }

    final chosenUrl = best?['url']?.toString();
    if (chosenUrl == null) return null;
    return Uri.parse(chosenUrl).hasScheme ? chosenUrl : '${_currentInstance}$chosenUrl';
  }

  VideoInfo? _parseVideoInfo(dynamic data, String base) {
    if (base.contains('invidious')) {
      final formats = (data['adaptiveFormats'] as List?)?.map((f) => _parseFormat(f)).whereType<VideoFormat>().toList() ?? [];
      return VideoInfo(
        videoId: data['videoId']?.toString() ?? '',
        title: data['title']?.toString() ?? '',
        author: data['author']?.toString() ?? '',
        duration: Duration(seconds: data['lengthSeconds']?.toInt() ?? 0),
        thumbnailUrl: (data['videoThumbnails'] as List?)?.last['url']?.toString(),
        formats: formats,
      );
    }
    return VideoInfo(
      videoId: data['videoId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      author: data['authorName']?.toString() ?? '',
      duration: Duration(seconds: data['duration']?.toInt() ?? 0),
      thumbnailUrl: data['thumbnail']?.toString(),
      formats: [],
    );
  }

  VideoFormat? _parseFormat(dynamic f) {
    if (f is! Map) return null;
    return VideoFormat(
      itag: f['itag']?.toString() ?? '',
      mimeType: f['mimeType']?.toString() ?? '',
      quality: f['quality']?.toString() ?? '',
      qualityLabel: f['qualityLabel']?.toString() ?? '',
      width: f['width']?.toInt() ?? 0,
      height: f['height']?.toInt() ?? 0,
      bitrate: f['bitrate']?.toInt() ?? 0,
      url: f['url']?.toString() ?? '',
      hasAudio: f['audioQuality'] != null || f['mimeType']?.toString().contains('audio') == true,
      hasVideo: f['qualityLabel'] != null,
    );
  }

  String? _extractVideoId(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url.startsWith('/') ? 'https://x$url' : url);
    if (uri == null) return null;
    return uri.queryParameters['v'] ?? uri.pathSegments.lastOrNull;
  }

  /// Get HLS manifest URL for native iOS downloading (AVAssetDownloadTask)
  Future<String?> getHLSManifestUrl(String videoId) async {
    for (final base in _getHealthyInstances()) {
      try {
        final response = await http.get(
          Uri.parse('$base/api/v1/streams/$videoId'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final streams = _extractStreams(data, base);
          if (streams != null) {
            for (final s in streams) {
              if (s is Map) {
                final mime = s['mimeType']?.toString() ?? '';
                final url = s['url']?.toString() ?? '';
                // Look for HLS manifest (m3u8)
                if (mime.contains('mpegurl') || mime.contains('vnd.apple.mpegurl') || url.contains('.m3u8')) {
                  _recordSuccess(base);
                  return Uri.parse(url).hasScheme ? url : '$base$url';
                }
              }
            }
          }
        }
        _recordFailure(base);
      } catch (e) {
        debugPrint('HLS manifest failed ($base): $e');
        _recordFailure(base);
      }
    }
    // Fallback: Direct YouTube HLS manifest
    return 'https://manifest.googlevideo.com/api/manifest/hls_variant/$videoId';
  }

  /// Get Invidious HLS URL
  Future<String?> getInvidiousHLSUrl(String videoId) async {
    for (final base in _invidiousInstances) {
      try {
        final response = await http.get(
          Uri.parse('$base/api/v1/videos/$videoId'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final formats = data['adaptiveFormats'] as List?;
          if (formats != null) {
            for (final f in formats) {
              if (f is Map) {
                final mime = f['mimeType']?.toString() ?? '';
                final url = f['url']?.toString() ?? '';
                if (mime.contains('mpegurl') || mime.contains('vnd.apple.mpegurl') || url.contains('.m3u8')) {
                  return Uri.parse(url).hasScheme ? url : '$base$url';
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _instanceChangeController.close();
  }
}

class InstanceHealth {
  final DateTime lastCheck;
  final int latencyMs;
  final int consecutiveFailures;
  final int totalRequests;
  final int successfulRequests;

  InstanceHealth({
    required this.lastCheck,
    required this.latencyMs,
    required this.consecutiveFailures,
    required this.totalRequests,
    required this.successfulRequests,
  });

  Map<String, dynamic> toJson() => {
    'lastCheck': lastCheck.toIso8601String(),
    'latencyMs': latencyMs,
    'consecutiveFailures': consecutiveFailures,
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
  };

  factory InstanceHealth.fromJson(Map<String, dynamic> json) => InstanceHealth(
    lastCheck: DateTime.parse(json['lastCheck'] as String),
    latencyMs: json['latencyMs'] as int,
    consecutiveFailures: json['consecutiveFailures'] as int,
    totalRequests: json['totalRequests'] as int,
    successfulRequests: json['successfulRequests'] as int,
  );
}

class VideoInfo {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;
  final List<VideoFormat> formats;

  const VideoInfo({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnailUrl,
    required this.formats,
  });
}

class VideoFormat {
  final String itag;
  final String mimeType;
  final String quality;
  final String qualityLabel;
  final int width;
  final int height;
  final int bitrate;
  final String url;
  final bool hasAudio;
  final bool hasVideo;

  const VideoFormat({
    required this.itag,
    required this.mimeType,
    required this.quality,
    required this.qualityLabel,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.url,
    required this.hasAudio,
    required this.hasVideo,
  });
}