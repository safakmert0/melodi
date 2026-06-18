class StringSimilarity {
  static double jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final matchWindow = (s1.length > s2.length ? s1.length : s2.length) ~/ 2 - 1;
    if (matchWindow < 1) matchWindow = 1;

    final s1Matches = List.filled(s1.length, false);
    final s2Matches = List.filled(s2.length, false);

    var matches = 0;
    var transpositions = 0;

    for (var i = 0; i < s1.length; i++) {
      final start = (i - matchWindow) > 0 ? (i - matchWindow) : 0;
      final end = (i + matchWindow + 1) < s2.length ? (i + matchWindow + 1) : s2.length;

      for (var j = start; j < end; j++) {
        if (s2Matches[j]) continue;
        if (s1.codeUnitAt(i) != s2.codeUnitAt(j)) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    var k = 0;
    for (var i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (k < s2.length && !s2Matches[k]) k++;
      if (k < s2.length && s1.codeUnitAt(i) != s2.codeUnitAt(k)) {
        transpositions++;
      }
      k++;
    }

    final jaro = ((matches / s1.length) +
            (matches / s2.length) +
            ((matches - transpositions / 2) / matches)) /
        3.0;

    var prefix = 0;
    final prefixLimit = s1.length < 4 ? s1.length : 4;
    final minLen = s1.length < s2.length ? s1.length : s2.length;
    for (var i = 0; i < prefixLimit && i < minLen; i++) {
      if (s1.codeUnitAt(i) == s2.codeUnitAt(i)) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + (prefix * 0.1 * (1 - jaro));
  }
}

class TrackMatcher {
  static double score(String queryTitle, String queryArtist, String targetTitle, String targetArtist) {
    final normQueryTitle = _normalize(queryTitle);
    final normQueryArtist = _normalize(queryArtist);
    final normTargetTitle = _normalize(targetTitle);
    final normTargetArtist = _normalize(targetArtist);

    final titleScore = StringSimilarity.jaroWinkler(normQueryTitle, normTargetTitle);
    if (queryArtist.isEmpty || targetArtist.isEmpty) {
      return titleScore;
    }

    final artistScore = StringSimilarity.jaroWinkler(normQueryArtist, normTargetArtist);
    return titleScore * 0.6 + artistScore * 0.4;
  }

  static double scoreWithDuration(
    String queryTitle, String queryArtist, int queryDurationMs,
    String targetTitle, String targetArtist, int targetDurationMs,
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

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

extension StringSimilarityExtension on String {
  double similarityTo(String other) => StringSimilarity.jaroWinkler(this, other);
}
