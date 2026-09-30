import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database_service.dart';
import '../explode_stream_service.dart';
import '../music_source.dart';
import '../stream_quality.dart';
import '../track_matcher.dart';
import '../webview_stream_service.dart';
import '../ytmusic_service.dart';
import 'hifi_source.dart';

/// YouTube kaynağı (JollyTone katmani): arama InnerTube, akis/indirme
/// youtube_explode cok istemcili manifest + imza cozme ile.
/// Ne sunucu ister ne hesap.
class YouTubeSource implements MusicSource {
  @override
  MusicSourceType get type => MusicSourceType.youtube;

  @override
  String get name => 'YouTube';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final items =
          await YtMusicService.instance.search(trimmed, limit: limit);
      final tracks = <OnlineTrack>[];
      for (final m in items) {
        final track = _mapItem(m);
        if (track != null) tracks.add(track);
        if (tracks.length >= limit) break;
      }
      return tracks;
    } catch (e) {
      debugPrint('YouTube search error: $e');
      return const [];
    }
  }

  OnlineTrack? _mapItem(Map<String, dynamic> m) {
    try {
      final id = (m['id'] ?? '').toString().trim();
      if (id.isEmpty) return null;
      final title =
          (m['name'] ?? m['title'] ?? 'Bilinmeyen parça').toString().trim();
      final rawArtist = m['artists'] ?? m['artist'] ?? m['author'] ?? '';
      final artist = rawArtist is List
          ? rawArtist.map((e) => e.toString()).join(', ')
          : rawArtist.toString().trim();
      final album =
          (m['album_name'] ?? m['album'] ?? '').toString().trim();
      final duration = _durationOf(m);
      final thumb =
          (m['thumbnail'] ?? m['coverUrl'] ?? m['cover_url'] ?? '').toString();
      return OnlineTrack(
        id: id,
        title: title.isEmpty ? 'Bilinmeyen parça' : title,
        artist: artist.isEmpty ? 'Bilinmeyen sanatçı' : artist,
        album: album.isEmpty ? null : album,
        duration: duration,
        thumbnailUrl: thumb.isEmpty ? null : thumb,
        source: MusicSourceType.youtube,
        itemType: (m['item_type'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Duration _durationOf(Map<String, dynamic> m) {
    for (final key in [
      'duration_ms',
      'durationMs',
      'duration',
      'durationSec',
      'duration_sec',
      'length',
    ]) {
      final v = m[key];
      if (v == null) continue;
      final n = v is num ? v.toDouble() : double.tryParse(v.toString());
      if (n == null || n <= 0) continue;
      // ms mi saniye mi ayırt et: 10000 üstü ms kabul edilir.
      if (key.toLowerCase().contains('ms') || n > 10000) {
        return Duration(milliseconds: n.round());
      }
      return Duration(seconds: n.round());
    }
    return Duration.zero;
  }

  static const _probeUA =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  /// googlevideo URL'sini kisa Range istegiyle dogrular.
  /// true = calar, false = olu (403/bos), null = kararsiz (gecilir).
  /// Sadece googlevideo hostlarina uygulanir; proxy/kendi sunucusu aynen gecer.
  static Future<bool?> _probeAudioUrl(String url) async {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (!uri.host.contains('googlevideo.com')) return null;
    try {
      final resp = await http
          .get(uri, headers: {'Range': 'bytes=0-1023', 'User-Agent': _probeUA})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 403) return false;
      if (resp.statusCode == 200 || resp.statusCode == 206) {
        return resp.bodyBytes.isNotEmpty ? true : false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// googlevideo mime parametresinden opus/webm eleme.
  /// AVPlayer bunlari acamaz (-1); o katman en sona birakilir.
  static bool _isOpusLike(String url) {
    try {
      final mime =
          Uri.parse(url).queryParameters['mime']?.toLowerCase() ?? '';
      return mime.contains('opus') || mime.contains('webm');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    final videoId = track.id.trim();
    debugPrint('🔍 YouTubeSource.getStreamUrl START: $videoId');
    // Kalite: hucrede hucre ayari, degilse akış ayari (veri tasarrufu).
    final quality = await effectiveStreamingQuality();
    final cap = qualityCapKbps(quality);
    String? opusFallback;
    // 1) Backend proxy (yt-dlp Range): stabil, expire olmaz, AVPlayer uyumlu
    // m4a döner. HEAD ile dogrulanmis gelir, aynen gecer.
    if (videoId.isNotEmpty) {
      try {
        final proxy = await backendStreamUrl(videoId, quality: quality);
        if (proxy != null) {
          debugPrint('✅ Backend proxy OK: $videoId');
          return proxy;
        }
        debugPrint('❌ Backend proxy returned null');
      } catch (e) {
        debugPrint('❌ Backend proxy exception: $e');
      }
    }
    // 2) Gizli tarayici (gercek oynatici baglami: bot duvari yok,
    // n/imza gecerli). musx tarifidir.
    try {
      debugPrint('🌐 WebViewStreamService resolving: $videoId');
      final web = await WebViewStreamService.instance
          .resolveAudio(videoId)
          .timeout(const Duration(seconds: 40), onTimeout: () => null);
      final webUrl = web?['url']?.toString() ?? '';
      if (webUrl.isNotEmpty) {
        if (_isOpusLike(webUrl)) {
          opusFallback ??= webUrl;
          debugPrint('⏳ WebView opus, sona birakildi: $videoId');
        } else {
          final ok = await _probeAudioUrl(webUrl);
          if (ok != false) {
            debugPrint('✅ WebView OK: $videoId');
            return webUrl;
          }
          debugPrint('❌ WebView URL olu (403): $videoId');
        }
      } else {
        debugPrint('❌ WebView returned empty URL');
      }
    } catch (e) {
      debugPrint('❌ WebView exception: $e');
    }
    // 3) Cihazda el yapimi InnerTube (ANDROID 19.29.1, AAC oncelikli).
    // Cozulmemis n/imza linkleri AVPlayer'da -1 verir; probe'dan
    // gecemeyen katman atlanir.
    try {
      debugPrint('🎵 InnerTube (19.29.1) resolving: $videoId');
      final innerTube =
          await YtMusicService.instance.getM4aStreamUrl(videoId);
      if (innerTube != null && innerTube.isNotEmpty) {
        if (_isOpusLike(innerTube)) {
          opusFallback ??= innerTube;
          debugPrint('⏳ InnerTube opus, sona birakildi: $videoId');
        } else {
          final ok = await _probeAudioUrl(innerTube);
          if (ok != false) {
            debugPrint('✅ InnerTube OK: $videoId');
            return innerTube;
          }
          debugPrint('❌ InnerTube URL olu (403): $videoId');
        }
      } else {
        debugPrint('❌ InnerTube returned empty');
      }
    } catch (e) {
      debugPrint('❌ InnerTube exception: $e');
    }
    // 4) Cihazda explode (dogrulanmis AAC URL).
    try {
      debugPrint('💥 ExplodeStreamService resolving: $videoId');
      final direct =
          await ExplodeStreamService.instance.getStreamUrl(videoId, maxBitrateKbps: cap);
      if (direct != null && direct.isNotEmpty) {
        if (_isOpusLike(direct)) {
          opusFallback ??= direct;
          debugPrint('⏳ Explode opus, sona birakildi: $videoId');
        } else {
          final ok = await _probeAudioUrl(direct);
          if (ok != false) {
            debugPrint('✅ Explode OK: $videoId');
            return direct;
          }
          debugPrint('❌ Explode URL olu (403): $videoId');
        }
      } else {
        debugPrint('❌ Explode returned empty');
      }
    } catch (e) {
      debugPrint('❌ Explode exception: $e');
    }
    if (opusFallback != null) {
      debugPrint('⚠️ Opus yedegi donuluyor: $videoId');
      return opusFallback;
    }
    debugPrint('🚫 ALL METHODS FAILED for: $videoId');
    return null;
  }

  /// Backend `/api/stream/{videoId}` adresini doğrular (HEAD, kısa timeout).
  /// Backend ayaktaysa ve video çözülüyorsa adresi döner, yoksa null.
  /// Doğrulama yapılmadan dönülmez: ölü proxy, explode yedeğini öldürürdü.
  static Future<String?> backendStreamUrl(String videoId,
      {String quality = 'high'}) async {
    final id = videoId.trim();
    if (id.isEmpty) return null;
    try {
      final base = await HiFiSource().baseUrl();
      if (base.isEmpty) return null;
      final q = (quality == 'lossless' || quality == 'auto' || quality.isEmpty)
          ? ''
          : '?quality=$quality';
      final proxy = '$base/api/stream/$id$q';
      final resp = await http
          .head(Uri.parse(proxy))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 || resp.statusCode == 206) return proxy;
      debugPrint('YouTube backend proxy HEAD ${resp.statusCode} for $id');
    } catch (e) {
      debugPrint('YouTube backend proxy check failed: $e');
    }
    return null;
  }

  /// Hızlı çalma çözümü: başlık/sanatçıdan YouTube karşılığını bulup
  /// backend proxy (yoksa explode) adresini döner. Sunucuda FLAC
  /// indirmeyi beklemez — Hi-Fi parçaları anında çalmak içindir.
  /// Kalite değil hız önceliklidir.
  Future<String?> getFastStreamUrlForMetadata({
    required String title,
    required String artist,
    int durationMs = 0,
  }) async {
    final bestId = await resolveVideoId(
      title: title,
      artist: artist,
      durationMs: durationMs,
    );
    if (bestId == null || bestId.isEmpty) return null;
    try {
      final proxy = await backendStreamUrl(bestId);
      if (proxy != null) return proxy;
      return await ExplodeStreamService.instance.getStreamUrl(bestId);
    } catch (e) {
      debugPrint('YouTube fast stream miss: $e');
      return null;
    }
  }

  /// Başlık/sanatçıdan en iyi YouTube video kimliğini bulur.
  /// Önce kalıcı önbelleğe bakar (tekrar çalmalar aramasız ~anında),
  /// yoksa YTM aramasıyla çözüp önbelleğe yazar. İndirme yedeği için de
  /// kullanılır (Hi-Fi olmazsa YouTube'tan indirme).
  Future<String?> resolveVideoId({
    required String title,
    required String artist,
    int durationMs = 0,
  }) async {
    final t = title.trim();
    final a = artist.trim();
    if (t.isEmpty) return null;
    final cacheKey =
        'ytid_${(a.isEmpty ? t : '$a - $t').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    try {
      final cached = await DatabaseService.instance.getSetting(cacheKey);
      if (cached != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(cached)) {
        return cached;
      }
    } catch (_) {}
    try {
      final results = await YtMusicService.instance
          .search(a.isEmpty ? t : '$a - $t', limit: 8)
          .timeout(const Duration(seconds: 12));
      String bestId = '';
      var bestScore = -1.0;
      for (final m in results) {
        final id = (m['id'] ?? '').toString().trim();
        if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) continue;
        var score = TrackMatcher.scoreWithDuration(
          t,
          a,
          durationMs,
          (m['name'] ?? '').toString(),
          (m['artists'] ?? '').toString(),
          0,
        );
        if ((m['item_type'] ?? '').toString() == 'song') score += 0.2;
        if (score > bestScore) {
          bestScore = score;
          bestId = id;
        }
      }
      if (bestId.isEmpty) return null;
      try {
        await DatabaseService.instance.setSetting(cacheKey, bestId);
      } catch (_) {}
      return bestId;
    } catch (e) {
      debugPrint('YouTube fast resolve miss: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
