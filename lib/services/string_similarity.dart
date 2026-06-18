class StringSimilarity {
  static double jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    var matchWindow = (s1.length > s2.length ? s1.length : s2.length) ~/ 2 - 1;
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

extension StringSimilarityExtension on String {
  double similarityTo(String other) => StringSimilarity.jaroWinkler(this, other);
}
