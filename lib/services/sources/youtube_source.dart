import 'package:flutter/foundation.dart';
import '../music_source.dart';
import '../ytmusic_service.dart';

/// YouTube kaynağı: uygulamaya gömülü ytmusic paketi üzerinden.
/// Ne sunucu ister ne hesap; arama + indirme paketin kendi hattıyla yapılır.
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
    try {
      return await YtMusicService.instance.getPlayablePath(
        trackId: track.id,
        title: track.title,
        artist: track.artist,
      );
    } catch (e) {
      debugPrint('YouTube stream error: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
