import 'dart:async';
import 'package:flutter/foundation.dart';
import 'music_source.dart';
import 'sources/youtube_music_source.dart';
import 'sources/jiosaavn_source.dart';
import 'sources/deezer_source.dart';
import 'sources/navidrome_source.dart';
import 'sources/hifi_source.dart';
import 'sources/apple_music_source.dart';
import 'sources/soundcloud_source.dart';

class MultiSourceSearch {
  static final MultiSourceSearch _instance = MultiSourceSearch._();
  factory MultiSourceSearch() => _instance;
  MultiSourceSearch._();

  final List<MusicSource> _sources = [
    NavidromeSource(),
    HiFiSource(),
    YouTubeMusicSource(),
    JioSaavnSource(),
    DeezerSource(),
    AppleMusicSource(),
    SoundCloudSource(),
  ];

  List<MusicSource> get sources => List.unmodifiable(_sources);

  /// Display ranking for search results. Full-track sources (those that can
  /// actually play/download the whole song) are shown first; preview-only
  /// catalogues such as Deezer (30s preview) are pushed to the bottom.
  static const Map<MusicSourceType, int> _fullTrackRank = {
    MusicSourceType.navidrome: 0,
    MusicSourceType.youtube: 1,
    MusicSourceType.jiosaavn: 2,
    MusicSourceType.appleMusic: 3,
    MusicSourceType.soundcloud: 4,
    MusicSourceType.hifi: 5,
  };

  int _displayRank(OnlineTrack track) {
    if (track.source.supportsFullTrack) {
      return _fullTrackRank[track.source] ?? 50;
    }
    return 100;
  }

  int _displayCompare(OnlineTrack a, OnlineTrack b) {
    final ra = _displayRank(a);
    final rb = _displayRank(b);
    if (ra != rb) return ra.compareTo(rb);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  StreamController<List<OnlineTrack>>? _controller;

  Stream<List<OnlineTrack>> searchAll(String query, {int limitPerSource = 10}) {
    _controller?.close();
    _controller = StreamController<List<OnlineTrack>>.broadcast();

    _performSearch(query, limitPerSource);
    return _controller!.stream;
  }

  Future<List<OnlineTrack>> searchAllSync(String query,
      {int limitPerSource = 10}) async {
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
    allTracks.sort(_displayCompare);
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
          allTracks.sort(_displayCompare);
          if (!controller.isClosed) {
            controller.add(List.from(allTracks));
          }
        } catch (e) {
          debugPrint('Search error on ${source.name}: $e');
        }
      });
      await Future.wait(futures);
      allTracks.sort(_displayCompare);
      if (!controller.isClosed) {
        controller.add(allTracks);
      }
    } catch (e) {
      debugPrint('Multi-source search error: $e');
    }
  }

  Future<String?> getStreamUrl(OnlineTrack track) async {
    // Deezer's public API exposes metadata and a 30-second preview only.
    // Never let preview-only sources enter the playback/download pipeline.
    if (!track.source.supportsFullTrack) return null;
    final source = _sources.firstWhere(
      (s) => s.type == track.source,
      orElse: () => _sources.first,
    );
    return await source.getStreamUrl(track);
  }

  /// Try to get stream URL with fallback across all sources.
  /// Preview-only catalogue results are resolved against a full-track source.
  /// Priority: the track's own full source first, then the user's personal
  /// Navidrome library, YouTube and JioSaavn.
  Future<String?> getStreamUrlWithFallback(
    OnlineTrack track, {
    String? query,
    Set<String> excludedUrls = const {},
    bool preferStableYouTubeReference = false,
  }) async {
    Future<String?> resolve(MusicSource source, OnlineTrack candidate) async {
      final url = preferStableYouTubeReference &&
              source.type == MusicSourceType.youtube &&
              candidate.id.trim().isNotEmpty
          ? 'youtube://${candidate.id.trim()}'
          : await source.getStreamUrl(candidate);
      final normalized = url?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          excludedUrls.contains(normalized)) {
        return null;
      }
      return normalized;
    }

    // 1. Try the track's own source only if it can provide a full track.
    final primarySource = _sources.firstWhere(
      (s) => s.type == track.source,
      orElse: () => _sources.first,
    );
    if (primarySource.type.supportsFullTrack) {
      try {
        final url = await resolve(primarySource, track);
        if (url != null) return url;
      } catch (_) {}
    }

    // 2. Fallback: search by query across other sources
    // Use the selected result's exact metadata; a broad UI query can resolve
    // to an unrelated first result.
    final searchQuery = '${track.artist} - ${track.title}'.trim();
    final fallbackOrder = _sources
        .where((s) => s.type != track.source && s.type.supportsFullTrack)
        .toList();
    // Prefer the user's own server, then broad public full-track sources.
    fallbackOrder.sort((a, b) {
      const priority = {
        MusicSourceType.navidrome: 0,
        MusicSourceType.youtube: 1,
        MusicSourceType.jiosaavn: 2,
        MusicSourceType.appleMusic: 3,
        MusicSourceType.soundcloud: 4,
      };
      return (priority[a.type] ?? 99).compareTo(priority[b.type] ?? 99);
    });

    for (final source in fallbackOrder) {
      try {
        final results = await source.search(searchQuery, limit: 5);
        results.sort(
            (a, b) => _matchScore(b, track).compareTo(_matchScore(a, track)));
        for (final result in results) {
          if (_matchScore(result, track) < 2) continue;
          final url = await resolve(source, result);
          if (url != null) return url;
        }
      } catch (_) {}
    }
    return null;
  }

  int _matchScore(OnlineTrack candidate, OnlineTrack requested) {
    final wantedTitle = _normalize(requested.title);
    final wantedArtist = _normalize(requested.artist.split(',').first);
    final title = _normalize(candidate.title);
    final artist = _normalize(candidate.artist);
    var score = 0;
    if (title == wantedTitle) {
      score += 5;
    } else if (title.contains(wantedTitle) || wantedTitle.contains(title)) {
      score += 3;
    }
    if (wantedArtist.isNotEmpty && artist.contains(wantedArtist)) score += 3;
    final requestedSeconds = requested.duration.inSeconds;
    final candidateSeconds = candidate.duration.inSeconds;
    if (requestedSeconds > 0 && candidateSeconds > 0) {
      final delta = (requestedSeconds - candidateSeconds).abs();
      if (delta <= 3) {
        score += 2;
      } else if (delta > 20) {
        score -= 2;
      }
    }
    return score;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f\u0400-\u04ff]+'), ' ')
      .trim();

  void dispose() {
    for (final source in _sources) {
      source.dispose();
    }
    _controller?.close();
  }
}
