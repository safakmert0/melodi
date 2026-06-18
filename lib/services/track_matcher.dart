import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'ytmusic_service.dart';

class MatchResult {
  final String ytVideoId;
  final String title;
  final String artist;
  final double confidence;
  final String? album;
  final Duration? duration;
  final String? thumbnailUrl;
  final List<String> matchReasons;

  const MatchResult({
    required this.ytVideoId,
    required this.title,
    required this.artist,
    required this.confidence,
    this.album,
    this.duration,
    this.thumbnailUrl,
    this.matchReasons = const [],
  });
}

class TrackMatcher {
  final Future<List<YTMusicTrack>> Function(String query) _searchFn;

  TrackMatcher(this._searchFn);

  String normalizeTitle(String title) {
    final normalized = _normalizeUnicode(title);
    return normalized
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\(\[].*?(feat\.|ft\.|featuring).*?[\)\]]',
              caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'-\s*(feat\.|ft\.|featuring).*',
              caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String normalizeArtist(String artist) {
    final normalized = _normalizeUnicode(artist);
    return normalized
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\(\[].*?(feat\.|ft\.|featuring).*?[\)\]]',
              caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'-\s*(feat\.|ft\.|featuring).*',
              caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s*&\s*'), ' and ')
        .replaceAll(RegExp(r'\s*,\s*'), ' and ')
        .replaceAll(RegExp(r'\s*x\s*'), ' and ')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeUnicode(String s) {
    const withAccents =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñŠšŽžÐðÞþÆæŒœ';
    const withoutAccents =
        'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNnSsZzDdTHthAEaeOEoe';
    var result = s;
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  double levenshteinSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty) return b.isEmpty ? 1.0 : 0.0;
    if (b.isEmpty) return 0.0;

    final lenA = a.length;
    final lenB = b.length;
    final matrix = List.generate(lenA + 1, (i) => List.filled(lenB + 1, 0));

    for (var i = 0; i <= lenA; i++) matrix[i][0] = i;
    for (var j = 0; j <= lenB; j++) matrix[0][j] = j;

    for (var i = 1; i <= lenA; i++) {
      for (var j = 1; j <= lenB; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    final distance = matrix[lenA][lenB];
    final maxLen = lenA > lenB ? lenA : lenB;
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  MatchResult? findBestMatch(
    String spotifyTitle,
    String spotifyArtist, {
    String? album,
    int? durationMs,
    List<Map<String, dynamic>>? ytCandidates,
  }) {
    if (ytCandidates == null || ytCandidates.isEmpty) return null;

    final normTitle = normalizeTitle(spotifyTitle);
    final normArtist = normalizeArtist(spotifyArtist);

    MatchResult? bestResult;
    double bestScore = 0.0;

    for (final candidate in ytCandidates) {
      final ytTitle = candidate['title'] as String? ?? '';
      final ytArtist = candidate['artists'] as String? ?? '';
      final ytVideoId = candidate['videoId'] as String? ?? '';
      final ytAlbum = candidate['album'] as String?;
      final ytDurationMs = candidate['durationMs'] as int?;
      final ytThumbnail = candidate['thumbnailUrl'] as String?;

      if (ytVideoId.isEmpty) continue;

      final normYtTitle = normalizeTitle(ytTitle);
      final normYtArtist = normalizeArtist(ytArtist);

      final reasons = <String>[];
      double confidence = 0.0;

      if (normTitle == normYtTitle && normArtist == normYtArtist) {
        confidence = 1.0;
        reasons.add('exact_title_artist');
      }

      if (confidence < 0.95 && normTitle == normYtTitle && normArtist == normYtArtist) {
        confidence = 0.95;
        reasons.add('exact_normalized');
      }

      if (confidence < 0.85) {
        final titleSim = levenshteinSimilarity(normTitle, normYtTitle);
        if (titleSim > 0.85 && normArtist == normYtArtist) {
          confidence = titleSim * 0.95;
          reasons.add('fuzzy_title_exact_artist');
        }
      }

      if (confidence < 0.8) {
        final titleSim = levenshteinSimilarity(normTitle, normYtTitle);
        final artistSim = levenshteinSimilarity(normArtist, normYtArtist);
        if (titleSim > 0.8 && artistSim > 0.8) {
          confidence = (titleSim * 0.6 + artistSim * 0.4) * 0.9;
          reasons.add('fuzzy_title_artist');
        }
      }

      if (confidence < 0.6) {
        final titleWords = normTitle.split(' ');
        final ytTitleWords = normYtTitle.split(' ');
        final commonWords =
            titleWords.where((w) => ytTitleWords.contains(w)).length;
        if (commonWords >= titleWords.length * 0.6 &&
            normArtist == normYtArtist) {
          confidence = (commonWords / titleWords.length) * 0.8;
          reasons.add('keyword_match');
        }
      }

      if (confidence > 0.0 &&
          durationMs != null &&
          ytDurationMs != null &&
          ytDurationMs > 0) {
        final durationDiff = (durationMs - ytDurationMs).abs();
        if (durationDiff <= 5000) {
          confidence = (confidence + 0.1).clamp(0.0, 1.0);
          reasons.add('duration_close');
        } else if (durationDiff > 30000) {
          confidence *= 0.5;
        }
      }

      if (confidence > 0.0 && album != null && ytAlbum != null) {
        if (normalizeTitle(album) == normalizeTitle(ytAlbum)) {
          confidence = (confidence + 0.05).clamp(0.0, 1.0);
          reasons.add('album_match');
        }
      }

      if (confidence > bestScore) {
        bestScore = confidence;
        bestResult = MatchResult(
          ytVideoId: ytVideoId,
          title: ytTitle,
          artist: ytArtist,
          confidence: confidence,
          album: ytAlbum,
          duration: ytDurationMs != null
              ? Duration(milliseconds: ytDurationMs)
              : null,
          thumbnailUrl: ytThumbnail,
          matchReasons: reasons,
        );
      }
    }

    return bestResult;
  }

  Future<List<Map<String, dynamic>>> searchYTWithContext(
    String title,
    String artist, {
    String? album,
  }) async {
    final queries = <String>[
      '$title $artist',
      '$title $artist audio',
      '$artist $title lyrics',
    ];

    final seen = <String>{};
    final results = <Map<String, dynamic>>[];

    for (final query in queries) {
      try {
        final tracks = await _searchFn(query);
        for (final track in tracks) {
          if (seen.add(track.videoId)) {
            results.add(track.toJson());
          }
        }
      } catch (e) {
        debugPrint('TrackMatcher search error for "$query": $e');
      }
    }

    return results;
  }

  Future<MatchResult?> matchSpotifyTrackToYT(
    String spotifyTitle,
    String spotifyArtist, {
    String? album,
    int? durationMs,
  }) async {
    final candidates =
        await searchYTWithContext(spotifyTitle, spotifyArtist, album: album);
    if (candidates.isEmpty) return null;

    return findBestMatch(
      spotifyTitle,
      spotifyArtist,
      album: album,
      durationMs: durationMs,
      ytCandidates: candidates,
    );
  }

  Future<List<MatchResult>> batchMatch(
    List<Map<String, dynamic>> spotifyTracks, {
    void Function(int, int)? onProgress,
  }) async {
    final results = <MatchResult>[];
    final total = spotifyTracks.length;

    for (var i = 0; i < total; i++) {
      final track = spotifyTracks[i];
      final title = track['title'] as String? ?? '';
      final artist = track['artist'] as String? ?? '';
      final album = track['album'] as String?;
      final durationMs = track['durationMs'] as int?;

      final result = await matchSpotifyTrackToYT(
        title,
        artist,
        album: album,
        durationMs: durationMs,
      );

      if (result != null) {
        results.add(result);
        final spotifyId = track['id'] as String?;
        if (spotifyId != null) {
          await DatabaseService.instance.cacheMatch(
              spotifyId, result.ytVideoId, result.confidence);
        }
      }

      onProgress?.call(i + 1, total);
    }

    return results;
  }

  static double score(
      String queryTitle,
      String queryArtist,
      String targetTitle,
      String targetArtist) {
    final matcher = TrackMatcher((_) async => []);
    final normQueryTitle = matcher.normalizeTitle(queryTitle);
    final normQueryArtist = matcher.normalizeArtist(queryArtist);
    final normTargetTitle = matcher.normalizeTitle(targetTitle);
    final normTargetArtist = matcher.normalizeArtist(targetArtist);

    final titleScore =
        matcher.levenshteinSimilarity(normQueryTitle, normTargetTitle);
    if (queryArtist.isEmpty || targetArtist.isEmpty) {
      return titleScore;
    }

    final artistScore =
        matcher.levenshteinSimilarity(normQueryArtist, normTargetArtist);
    return titleScore * 0.6 + artistScore * 0.4;
  }

  static double scoreWithDuration(
    String queryTitle,
    String queryArtist,
    int queryDurationMs,
    String targetTitle,
    String targetArtist,
    int targetDurationMs,
  ) {
    final base = score(queryTitle, queryArtist, targetTitle, targetArtist);
    if (base < 0.01) return 0.0;

    if (queryDurationMs > 0 && targetDurationMs > 0) {
      final ratio = queryDurationMs / targetDurationMs;
      if (ratio < 0.5 || ratio > 2.0) return base * 0.3;
      if (ratio < 0.7 || ratio > 1.4) return base * 0.7;
    }

    return base;
  }
}
