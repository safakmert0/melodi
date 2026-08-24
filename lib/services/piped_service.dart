import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/extension.dart';
import 'database_service.dart';
import 'extension_service.dart';
import 'music_source.dart';

/// Kendi sunucusuna gerek kalmadan YouTube yedeği: herkese açık Piped
/// örnekleri üzerinden arama ve ses akışı.
///
/// Örnek listesi üç kaynaktan birleşir (öncelik sırasıyla):
/// 1. Kullanıcının kurduğu `piped` protokolü eklentileri
/// 2. Resmî depoda tutulan canlı liste (data/piped-instances.json)
/// 3. Uygulamaya gömülü tohum adresler
///
/// Liste repodan tazelenebildiği için bir örnek kapansa uygulama yayını
/// yapmadan yenisi devreye alınır.
class PipedService {
  PipedService._();
  static final PipedService _instance = PipedService._();
  factory PipedService() => _instance;
  static PipedService get instance => _instance;

  /// Uygulama içi gömülü tohum örnekler; en az biri ayaktayken yedek çalışır.
  static const List<String> seedInstances = [
    'https://api.piped.private.coffee',
  ];

  /// Canlı örnek listesinin resmî depodaki adresi.
  static const String instanceListUrl =
      'https://raw.githubusercontent.com/safakmert0/melodi-extensions/main/data/piped-instances.json';

  static const String _cacheKey = 'piped_instances_cache';
  static const Duration _listTtl = Duration(hours: 12);
  static const Duration _searchTimeout = Duration(seconds: 10);
  static const Duration _streamTimeout = Duration(seconds: 15);
  static const Duration _cooldown = Duration(minutes: 10);

  final DatabaseService _db = DatabaseService.instance;
  List<String> _fetchedInstances = const [];
  DateTime? _fetchedAt;
  bool _listLoading = false;
  final Map<String, DateTime> _badUntil = {};

  /// Birleşik örnek listesi; sağlıksız işaretliler sona atılır.
  Future<List<String>> instances() async {
    await _ensureList();
    final fromExtensions = await ExtensionService.instance
        .resolveEndpoints(ExtensionKind.backend, ExtensionProtocol.piped)
        .catchError((_) => <String>[]);
    final all = [
      ...fromExtensions,
      ..._fetchedInstances,
      ...seedInstances,
    ];
    final seen = <String>{};
    final unique = <String>[];
    for (final raw in all) {
      final url = raw.trim().replaceAll(RegExp(r'/+$'), '');
      if (url.isEmpty || !seen.add(url)) continue;
      unique.add(url);
    }
    final now = DateTime.now();
    unique.sort((a, b) {
      final aBad = _badUntil[a]?.isAfter(now) ?? false;
      final bBad = _badUntil[b]?.isAfter(now) ?? false;
      if (aBad == bBad) return 0;
      return aBad ? 1 : -1;
    });
    return unique;
  }

  void markUnhealthy(String baseUrl) {
    _badUntil[baseUrl] = DateTime.now().add(_cooldown);
  }

  /// Piped araması; hiçbir örnek yanıt vermezse boş liste döner.
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    for (final base in await instances()) {
      try {
        final uri = Uri.parse('$base/search').replace(queryParameters: {
          'q': trimmed,
          'filter': 'videos',
        });
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(_searchTimeout);
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final items = data['items'];
        if (items is! List) continue;
        final tracks = <OnlineTrack>[];
        for (final item in items) {
          if (item is! Map) continue;
          final id = _videoIdFromUrl(item['url']?.toString() ?? '');
          if (id == null) continue;
          final seconds = (item['duration'] as num?)?.toInt() ?? 0;
          // Canlı yayınlar ve süre bilgisi olmayanlar çalma zincirine girmez.
          if (seconds <= 0) continue;
          tracks.add(OnlineTrack(
            id: id,
            title: item['title']?.toString() ?? 'Bilinmeyen',
            artist: item['uploaderName']?.toString() ?? 'Bilinmeyen',
            duration: Duration(seconds: seconds),
            thumbnailUrl: item['thumbnail']?.toString(),
            source: MusicSourceType.youtube,
          ));
          if (tracks.length >= limit) break;
        }
        if (tracks.isNotEmpty) return tracks;
      } catch (e) {
        debugPrint('Piped search failed ($base): $e');
      }
      markUnhealthy(base);
    }
    return const [];
  }

  /// Parçanın ses akışını döndürür; tercihen örneğin proxy'si üzerinden
  /// (böylece cihaz IP'sinin YouTube erişimi gerekmez). Bulunamazsa null.
  Future<String?> streamUrl(String videoId) async {
    for (final base in await instances()) {
      try {
        final response = await http
            .get(Uri.parse('$base/streams/$videoId'),
                headers: {'Accept': 'application/json'})
            .timeout(_streamTimeout);
        if (response.statusCode != 200) {
          markUnhealthy(base);
          continue;
        }
        final data = jsonDecode(response.body);
        final streams = data['audioStreams'];
        if (streams is! List || streams.isEmpty) continue;

        Map<dynamic, dynamic>? best;
        int bestBitrate = -1;
        bool bestProxied = false;
        for (final s in streams) {
          if (s is! Map) continue;
          final mime = s['mimeType']?.toString() ?? '';
          if (!mime.contains('mp4')) continue;
          final url = s['url']?.toString() ?? '';
          if (url.isEmpty) continue;
          final bitrate = (s['bitrate'] as num?)?.toInt() ?? 0;
          final proxied = url.contains('/proxy') || url.contains('proxy.');
          // Proxy'li adresler her koşulda tercih edilir.
          if (best == null || (proxied && !bestProxied) ||
              (proxied == bestProxied && bitrate > bestBitrate)) {
            best = s;
            bestBitrate = bitrate;
            bestProxied = proxied;
          }
        }
        final chosenUrl = best?['url']?.toString();
        if (chosenUrl != null && chosenUrl.isNotEmpty) {
          return Uri.parse(chosenUrl).hasScheme
              ? chosenUrl
              : '$base$chosenUrl';
        }
      } catch (e) {
        debugPrint('Piped stream failed ($base): $e');
      }
      markUnhealthy(base);
    }
    return null;
  }

  Future<void> _ensureList() async {
    final fresh =
        _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _listTtl;
    if (fresh || _listLoading) return;
    _listLoading = true;
    try {
      try {
        final cached = await _db.getSetting(_cacheKey);
        if (cached != null && cached.isNotEmpty) {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            _fetchedInstances = decoded.whereType<String>().toList();
            _fetchedAt = DateTime.now().subtract(const Duration(hours: 6));
          }
        }
      } catch (_) {}

      final response = await http
          .get(Uri.parse(instanceListUrl),
              headers: {'Accept': 'application/json'})
          .timeout(_searchTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['instances'];
        if (list is List) {
          _fetchedInstances = list
              .map((e) => e.toString().trim())
              .where((e) => e.startsWith('http'))
              .toList();
          _fetchedAt = DateTime.now();
          try {
            await _db.setSetting(_cacheKey, jsonEncode(_fetchedInstances));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Piped instance list refresh failed: $e');
      _fetchedAt ??= DateTime.now();
    } finally {
      _listLoading = false;
    }
  }

  String? _videoIdFromUrl(String url) {
    if (url.isEmpty) return null;
    final raw = url.startsWith('/') ? 'https://x$url' : url;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    final last = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    return (last == null || last.isEmpty) ? null : last;
  }
}
