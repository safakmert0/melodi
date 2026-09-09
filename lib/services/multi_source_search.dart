import 'dart:async';
import 'package:flutter/foundation.dart';
import 'music_source.dart';
import 'sources/youtube_source.dart';

/// Çevrimiçi tek yapı: YouTube (hesapsız, sunucusuz).
class MultiSourceSearch {
  static final MultiSourceSearch _instance = MultiSourceSearch._();
  factory MultiSourceSearch() => _instance;
  MultiSourceSearch._();

  final List<MusicSource> _sources = [
    YouTubeSource(),
  ];

  List<MusicSource> get sources => List.unmodifiable(_sources);

  static const Map<MusicSourceType, int> _fullTrackRank = {
    MusicSourceType.youtube: 0,
  };

  int _displayRank(OnlineTrack track) {
    if (track.source.supportsFullTrack) {
      return _fullTrackRank[track.source] ?? 50;
    }
    return 100;
  }

  int _displayCompare(OnlineTrack a, OnlineTrack b, [String query = '']) {
    final relevanceA = _queryRelevance(a, query);
    final relevanceB = _queryRelevance(b, query);
    if (relevanceA != relevanceB) return relevanceB.compareTo(relevanceA);
    // Müzik sürümü (art track) önce: klipler gömülü oynatıcıda ve
    // doğrudan akışta daha sık engellenir (embed kapalı / giriş koruması).
    if (a.isVideo != b.isVideo) return a.isVideo ? 1 : -1;
    final ra = _displayRank(a);
    final rb = _displayRank(b);
    if (ra != rb) return ra.compareTo(rb);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  int _queryRelevance(OnlineTrack track, String query) {
    final wanted = _normalize(query);
    if (wanted.isEmpty) return 0;
    final title = _normalize(track.title);
    final artist = _normalize(track.artist);
    var score = 0;
    if (title == wanted) score += 100;
    if (title.startsWith(wanted)) score += 45;
    if (title.contains(wanted)) score += 30;
    final tokens = wanted.split(' ').where((token) => token.length > 1);
    for (final token in tokens) {
      if (title.split(' ').contains(token)) score += 12;
      if (artist.split(' ').contains(token)) score += 8;
    }
    return score;
  }

  List<OnlineTrack> _rankedUnique(List<OnlineTrack> tracks, String query) {
    final best = <String, OnlineTrack>{};
    for (final track in tracks) {
      final durationBucket = track.duration.inSeconds ~/ 3;
      final key =
          '${_normalize(track.title)}|${_normalize(track.artist)}|$durationBucket';
      final current = best[key];
      if (current == null || _displayRank(track) < _displayRank(current)) {
        best[key] = track;
      }
    }
    final result = best.values.toList();
    result.sort((a, b) => _displayCompare(a, b, query));
    return result;
  }

  StreamController<List<OnlineTrack>>? _controller;

  // Brief cache of resolved stream URLs so repeated playback/download attempts
  // for the same track don't re-resolve through the network every time.
  final Map<String, _CachedStreamUrl> _streamUrlCache = {};
  static const Duration _streamUrlCacheTtl = Duration(minutes: 3);

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
    return _rankedUnique(results.expand((list) => list).toList(), query);
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
          final ranked = _rankedUnique(allTracks, query);
          if (!controller.isClosed) {
            controller.add(ranked);
          }
        } catch (e) {
          debugPrint('Search error on ${source.name}: $e');
        }
      });
      await Future.wait(futures);
      final ranked = _rankedUnique(allTracks, query);
      if (!controller.isClosed) {
        controller.add(ranked);
      }
    } catch (e) {
      debugPrint('Multi-source search error: $e');
    }
  }

  Future<String?> getStreamUrl(OnlineTrack track) async {
    if (!track.source.supportsFullTrack) return null;
    final cacheKey = '${track.source}:${track.id}';
    final cached = _streamUrlCache[cacheKey];
    if (cached != null && !cached.isExpired) return cached.url;
    final source = _sources.firstWhere(
      (s) => s.type == track.source,
      orElse: () => _sources.first,
    );
    final url = await source.getStreamUrl(track);
    if (url != null) _streamUrlCache[cacheKey] = _CachedStreamUrl(url);
    return url;
  }

  Future<void> prefetchStreamUrls(Iterable<OnlineTrack> tracks) async {
    await Future.wait(tracks.take(4).map((track) async {
      if (!track.source.supportsFullTrack) return;
      // YouTube çözümleme dosyanın tamamını indirebilir; aramada önden indirme.
      if (track.source == MusicSourceType.youtube) return;
      try {
        await getStreamUrl(track).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }));
  }

  Future<String?> getStreamUrlWithFallback(
    OnlineTrack track, {
    String? query,
    Set<String> excludedUrls = const {},
    bool preferStableYouTubeReference = false,
  }) async {
    if (track.source.supportsFullTrack) {
      try {
        final url = await getStreamUrl(track);
        final normalized = url?.trim();
        if (normalized != null &&
            normalized.isNotEmpty &&
            !excludedUrls.contains(normalized)) {
          return normalized;
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
      final toleranceSeconds = (requestedSeconds * 0.10).round().clamp(12, 30);
      if (delta <= 3) {
        score += 3;
      } else if (delta > toleranceSeconds) {
        // Title/artist alone must never select an extended mix, video outro or
        // unrelated upload that is minutes longer than the requested track.
        score -= 9;
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

  void clearStreamCache() => _streamUrlCache.clear();
}

class _CachedStreamUrl {
  _CachedStreamUrl(this.url)
      : expiresAt =
            DateTime.now().add(MultiSourceSearch._streamUrlCacheTtl);

  final String url;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
