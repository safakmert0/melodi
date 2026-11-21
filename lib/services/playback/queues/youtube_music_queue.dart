import 'dart:async';
import 'package:audio_service/audio_service.dart';

import 'queue.dart';
import '../../music_source.dart';
import '../../ytmusic_service.dart';

class YouTubeMusicQueue extends Queue {
  String _endpoint;
  final OnlineTrack? _preloadTrack;
  String? _continuation;
  List<OnlineTrack> _cachedTracks = [];
  int _mediaItemIndex = 0;

  /// Factory constructor for radio queue (from a seed track)
  factory YouTubeMusicQueue.radio(OnlineTrack song) {
    return YouTubeMusicQueue(
      endpoint: 'watch_endpoint/${song.id}',
      preloadTrack: song,
    );
  }

  /// Factory constructor for album queue
  factory YouTubeMusicQueue.album(String browseId) {
    return YouTubeMusicQueue(endpoint: 'browse/$browseId');
  }

  /// Factory constructor for playlist queue
  factory YouTubeMusicQueue.playlist(String playlistId) {
    return YouTubeMusicQueue(endpoint: 'playlist/$playlistId');
  }

  /// Factory constructor for artist queue
  factory YouTubeMusicQueue.artist(String artistId) {
    return YouTubeMusicQueue(endpoint: 'artist/$artistId');
  }

  YouTubeMusicQueue({
    required String endpoint,
    OnlineTrack? preloadTrack,
  })  : _endpoint = endpoint,
        _preloadTrack = preloadTrack;

  @override
  Future<QueueStatus> getInitialStatus() async {
    if (_preloadTrack != null && _cachedTracks.isEmpty) {
      _cachedTracks.add(_preloadTrack!);
      _mediaItemIndex = 0;
    }

    if (_cachedTracks.isEmpty) {
      final nextResult = await YtMusicService.instance.next(
        _endpoint,
        _continuation,
      );

      if (nextResult != null) {
        _endpoint = nextResult['endpoint'] ?? _endpoint;
        _continuation = nextResult['continuation'];
        final items = nextResult['items'] as List? ?? [];
        _cachedTracks = items
            .map((m) => _mapItem(m))
            .whereType<OnlineTrack>()
            .toList();
        _mediaItemIndex = nextResult['currentIndex'] as int? ?? 0;
      }
    }

    return QueueStatus(
      title: _cachedTracks.isNotEmpty ? _cachedTracks.first.album ?? 'YouTube Music' : 'YouTube Music',
      items: _cachedTracks.map((t) => OnlineTrackToMediaItem(t).toMediaItem()).toList(),
      mediaItemIndex: _mediaItemIndex,
    );
  }

  @override
  bool get hasNextPage => _continuation != null;

  @override
  Future<List<MediaItem>> nextPage() async {
    if (_continuation == null) return [];

    final nextResult = await YtMusicService.instance.next(
      _endpoint,
      _continuation,
    );

    if (nextResult == null) return [];

    _endpoint = nextResult['endpoint'] ?? _endpoint;
    _continuation = nextResult['continuation'];
    final items = nextResult['items'] as List? ?? [];
    final newTracks = items
        .map((m) => _mapItem(m))
        .whereType<OnlineTrack>()
        .toList();

    _cachedTracks.addAll(newTracks);
    return newTracks.map((t) => OnlineTrackToMediaItem(t).toMediaItem()).toList();
  }

  OnlineTrack? _mapItem(Map<String, dynamic> m) {
    try {
      final id = (m['id'] ?? '').toString().trim();
      if (id.isEmpty) return null;
      final title = (m['name'] ?? m['title'] ?? 'Bilinmeyen parça').toString().trim();
      final rawArtist = m['artists'] ?? m['artist'] ?? m['author'] ?? '';
      final artist = rawArtist is List
          ? rawArtist.map((e) => e.toString()).join(', ')
          : rawArtist.toString().trim();
      final album = (m['album_name'] ?? m['album'] ?? '').toString().trim();
      final duration = _durationOf(m);
      final thumb = (m['thumbnail'] ?? m['coverUrl'] ?? m['cover_url'] ?? '').toString();

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
      if (key.toLowerCase().contains('ms') || n > 10000) {
        return Duration(milliseconds: n.round());
      }
      return Duration(seconds: n.round());
    }
    return Duration.zero;
  }

  @override
  Future<void> dispose() async {
    _cachedTracks.clear();
    _continuation = null;
  }
}