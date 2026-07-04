import 'dart:async';
import 'package:flutter/foundation.dart';
import 'music_source.dart';
import 'sources/youtube_source.dart';
import 'sources/jiosaavn_source.dart';
import 'sources/deezer_source.dart';
import 'sources/lastfm_source.dart';

class MultiSourceSearch {
  static final MultiSourceSearch _instance = MultiSourceSearch._();
  factory MultiSourceSearch() => _instance;
  MultiSourceSearch._();

  final List<MusicSource> _sources = [
    YouTubeMusicSource(),
    JioSaavnSource(),
    DeezerSource(),
    LastFmSource(),
  ];

  List<MusicSource> get sources => List.unmodifiable(_sources);

  StreamController<List<OnlineTrack>>? _controller;

  Stream<List<OnlineTrack>> searchAll(String query, {int limitPerSource = 10}) {
    _controller?.close();
    _controller = StreamController<List<OnlineTrack>>.broadcast();

    _performSearch(query, limitPerSource);
    return _controller!.stream;
  }

  Future<List<OnlineTrack>> searchAllSync(String query, {int limitPerSource = 10}) async {
    final futures = _sources.map((source) async {
      try {
        return await source.search(query, limit: limitPerSource);
      } catch (e) {
        debugPrint('Search error on ${source.name}: $e');
        return <OnlineTrack>[];
      }
    });
    final results = await Future.wait(futures);
    final allTracks = results.expand((list) => list).toList();
    return allTracks;
  }

  Future<void> _performSearch(String query, int limitPerSource) async {
    // Capture the controller for this search session so results don't leak
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    try {
      final allTracks = <OnlineTrack>[];
      final futures = _sources.map((source) async {
        try {
          final tracks = await source.search(query, limit: limitPerSource);
          allTracks.addAll(tracks);
          if (!controller.isClosed) {
            controller.add(List.from(allTracks));
          }
        } catch (e) {
          debugPrint('Search error on ${source.name}: $e');
        }
      });
      await Future.wait(futures);
      if (!controller.isClosed) {
        controller.add(allTracks);
      }
    } catch (e) {
      debugPrint('Multi-source search error: $e');
    }
  }

  Future<String?> getStreamUrl(OnlineTrack track) async {
    final source = _sources.firstWhere(
      (s) => s.type == track.source,
      orElse: () => _sources.first,
    );
    return await source.getStreamUrl(track);
  }

  /// Try to get stream URL with fallback across all sources.
  /// Priority: the track's own source first, then YouTube > JioSaavn > Deezer.
  Future<String?> getStreamUrlWithFallback(OnlineTrack track, {String? query}) async {
    // 1. Try the track's own source first
    final primarySource = _sources.firstWhere(
      (s) => s.type == track.source,
      orElse: () => _sources.first,
    );
    try {
      final url = await primarySource.getStreamUrl(track);
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}

    // 2. Fallback: search by query across other sources
    final searchQuery = query ?? '${track.artist} - ${track.title}';
    final fallbackOrder = _sources.where((s) => s.type != track.source).toList();
    // Prioritize YouTube, then JioSaavn, then Deezer
    fallbackOrder.sort((a, b) {
      const priority = {
        MusicSourceType.youtube: 0,
        MusicSourceType.jiosaavn: 1,
        MusicSourceType.deezer: 2,
        MusicSourceType.lastfm: 3,
      };
      return (priority[a.type] ?? 99).compareTo(priority[b.type] ?? 99);
    });

    for (final source in fallbackOrder) {
      try {
        final results = await source.search(searchQuery, limit: 3);
        for (final result in results) {
          final url = await source.getStreamUrl(result);
          if (url != null && url.isNotEmpty) return url;
        }
      } catch (_) {}
    }
    return null;
  }

  void dispose() {
    for (final source in _sources) {
      source.dispose();
    }
    _controller?.close();
  }
}
