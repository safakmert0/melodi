import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database_service.dart';
import '../explode_stream_service.dart';
import '../music_source.dart';
import '../track_matcher.dart';
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

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    final videoId = track.id.trim();
    // 1) Backend proxy (yt-dlp Range): stabil, expire olmaz, AVPlayer uyumlu
    // m4a döner. Cihazdan çözülen googlevideo URL'leri iOS'ta sık sık
    // -11849/-1 ile patlıyordu; proxy'de bu sorun yok.
    if (videoId.isNotEmpty) {
      try {
        final proxy = await backendStreamUrl(videoId);
        if (proxy != null) return proxy;
      } catch (e) {
        debugPrint('YouTube backend proxy miss: $e');
      }
    }
    // 2) Cihazda explode (dogrulanmis AAC URL).
    try {
      // Dogrudan akis URL'i: dosya indirmeden just_audio ile streaming.
      final direct =
          await ExplodeStreamService.instance.getStreamUrl(track.id);
      if (direct != null && direct.isNotEmpty) return direct;
    } catch (e) {
      debugPrint('YouTube stream error: $e');
    }
    try {
      final innerTube =
          await YtMusicService.instance.getStreamUrl(track.id);
      if (innerTube != null && innerTube.isNotEmpty) return innerTube;
    } catch (e) {
      debugPrint('YouTube InnerTube stream miss: $e');
    }
    return null;
  }

  /// Backend `/api/stream/{videoId}` adresini doğrular (HEAD, kısa timeout).
  /// Backend ayaktaysa ve video çözülüyorsa adresi döner, yoksa null.
  /// Doğrulama yapılmadan dönülmez: ölü proxy, explode yedeğini öldürürdü.
  static Future<String?> backendStreamUrl(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) return null;
    try {
      final base = await HiFiSource().baseUrl();
      if (base.isEmpty) return null;
      final proxy = '$base/api/stream/$id';
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
