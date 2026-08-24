import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'ai_service.dart';

class CollaborativeFilteringService {
  CollaborativeFilteringService._();
  static final CollaborativeFilteringService _instance = CollaborativeFilteringService._();
  factory CollaborativeFilteringService() => _instance;
  static CollaborativeFilteringService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;
  final AIService _ai = AIService.instance;

  final Map<String, Map<String, double>> _userItemMatrix = {};
  final Map<String, Map<String, double>> _itemSimilarity = {};
  bool _trained = false;

  Future<void> train({int minInteractions = 3}) async {
    final playHistory = await _getPlayHistory();
    _buildUserItemMatrix(playHistory, minInteractions);
    await _computeItemSimilarities();
    _trained = true;
    debugPrint('Collaborative filtering trained with ${_userItemMatrix.length} users');
  }

  Future<List<PlayEvent>> _getPlayHistory() async {
    final songs = await _db.getAllSongs();
    final events = <PlayEvent>[];

    for (final song in songs) {
      if (song.playCount != null && song.playCount! > 0) {
        for (var i = 0; i < song.playCount!; i++) {
          events.add(PlayEvent(
            userId: 'local_user',
            trackId: song.id,
            timestamp: song.lastPlayed ?? DateTime.now().subtract(Duration(days: i)),
            playDuration: song.duration,
          ));
        }
      }
    }

    return events;
  }

  void _buildUserItemMatrix(List<PlayEvent> events, int minInteractions) {
    final userCounts = <String, int>{};
    final itemCounts = <String, int>{};

    for (final event in events) {
      userCounts[event.userId] = (userCounts[event.userId] ?? 0) + 1;
      itemCounts[event.trackId] = (itemCounts[event.trackId] ?? 0) + 1;
    }

    final validUsers = userCounts.entries
        .where((e) => e.value >= minInteractions)
        .map((e) => e.key)
        .toSet();
    final validItems = itemCounts.entries
        .where((e) => e.value >= minInteractions)
        .map((e) => e.key)
        .toSet();

    for (final event in events) {
      if (!validUsers.contains(event.userId) || !validItems.contains(event.trackId)) continue;
      _userItemMatrix.putIfAbsent(event.userId, () => {})[event.trackId] =
          (_userItemMatrix[event.userId]?[event.trackId] ?? 0) + 1.0;
    }
  }

  Future<void> _computeItemSimilarities() async {
    final items = _userItemMatrix.values
        .expand((m) => m.keys)
        .toSet()
        .toList();

    for (var i = 0; i < items.length; i++) {
      final itemA = items[i];
      final vectorA = _getItemVector(itemA);
      if (vectorA.isEmpty) continue;

      for (var j = i + 1; j < items.length; j++) {
        final itemB = items[j];
        final vectorB = _getItemVector(itemB);
        if (vectorB.isEmpty) continue;

        final sim = _cosineSimilarity(vectorA, vectorB);
        if (sim > 0.1) {
          _itemSimilarity.putIfAbsent(itemA, () => {})[itemB] = sim;
          _itemSimilarity.putIfAbsent(itemB, () => {})[itemA] = sim;
        }
      }
    }
  }

  Map<String, double> _getItemVector(String itemId) {
    final vector = <String, double>{};
    for (final userEntry in _userItemMatrix.entries) {
      final rating = userEntry.value[itemId];
      if (rating != null) {
        vector[userEntry.key] = rating;
      }
    }
    return vector;
  }

  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    final keys = {...a.keys, ...b.keys};
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (final k in keys) {
      final va = a[k] ?? 0.0;
      final vb = b[k] ?? 0.0;
      dotProduct += va * vb;
      normA += va * va;
      normB += vb * vb;
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  Future<List<CFRecommendation>> getRecommendations(String userId, {int count = 20}) async {
    if (!_trained) await train();

    final userVector = _userItemMatrix[userId];
    if (userVector == null || userVector.isEmpty) return [];

    final scores = <String, double>{};
    final seenItems = userVector.keys.toSet();

    for (final itemEntry in userVector.entries) {
      final similarItems = _itemSimilarity[itemEntry.key];
      if (similarItems == null) continue;

      for (final simEntry in similarItems.entries) {
        if (seenItems.contains(simEntry.key)) continue;
        scores[simEntry.key] = (scores[simEntry.key] ?? 0.0) +
            itemEntry.value * simEntry.value;
      }
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(count).map((e) => CFRecommendation(
      trackId: e.key,
      score: e.value,
      reason: 'Users who liked similar tracks also liked this',
    )).toList();
  }

  Future<List<String>> getSimilarTracks(String trackId, {int count = 10}) async {
    if (!_trained) await train();

    final similar = _itemSimilarity[trackId];
    if (similar == null || similar.isEmpty) return [];

    final sorted = similar.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(count).map((e) => e.key).toList();
  }

  void dispose() {
    _userItemMatrix.clear();
    _itemSimilarity.clear();
    _trained = false;
  }
}

class PlayEvent {
  final String userId;
  final String trackId;
  final DateTime timestamp;
  final Duration? playDuration;

  const PlayEvent({
    required this.userId,
    required this.trackId,
    required this.timestamp,
    this.playDuration,
  });
}

class CFRecommendation {
  final String trackId;
  final double score;
  final String reason;

  const CFRecommendation({
    required this.trackId,
    required this.score,
    required this.reason,
  });
}

class RecommendationEngine {
  RecommendationEngine._();
  static final RecommendationEngine _instance = RecommendationEngine._();
  factory RecommendationEngine() => _instance;
  static RecommendationEngine get instance => _instance;

  final AIService _ai = AIService.instance;
  final CollaborativeFilteringService _cf = CollaborativeFilteringService.instance;
  final DatabaseService _db = DatabaseService.instance;

  Future<List<UnifiedRecommendation>> getUnifiedRecommendations({
    required String context,
    int count = 20,
  }) async {
    final recommendations = <UnifiedRecommendation>[];

    switch (context) {
      case 'home':
        recommendations.addAll(await _getHomeRecommendations(count));
        break;
      case 'now_playing':
        recommendations.addAll(await _getNowPlayingRecommendations(count));
        break;
      case 'artist':
        recommendations.addAll(await _getArtistRecommendations(count));
        break;
      case 'playlist':
        recommendations.addAll(await _getPlaylistRecommendations(count));
        break;
      case 'discovery':
        recommendations.addAll(await _getDiscoveryRecommendations(count));
        break;
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations.take(count).toList();
  }

  Future<List<UnifiedRecommendation>> _getHomeRecommendations(int count) async {
    final recs = <UnifiedRecommendation>[];

    final recent = await _getRecentlyPlayed(limit: 5);
    for (final trackId in recent) {
      final aiRecs = await _ai.getRecommendations(seedTrackId: trackId, count: 5);
      for (final r in aiRecs) {
        recs.add(UnifiedRecommendation(
          trackId: r.trackId,
          score: r.score * 0.9,
          source: 'ai_content',
          reason: 'Based on ${r.reasons.join(", ")}',
        ));
      }

      final cfRecs = await _cf.getSimilarTracks(trackId, count: 5);
      for (final t in cfRecs) {
        recs.add(UnifiedRecommendation(
          trackId: t,
          score: 0.8,
          source: 'collaborative',
          reason: 'Listeners of this also enjoyed',
        ));
      }
    }

    final newReleases = await _getNewReleases(limit: count ~/ 2);
    for (final t in newReleases) {
      recs.add(UnifiedRecommendation(
        trackId: t,
        score: 0.6,
        source: 'new_release',
        reason: 'New release',
      ));
    }

    return _deduplicate(recs);
  }

  Future<List<UnifiedRecommendation>> _getNowPlayingRecommendations(int count) async {
    return [];
  }

  Future<List<UnifiedRecommendation>> _getArtistRecommendations(int count) async {
    return [];
  }

  Future<List<UnifiedRecommendation>> _getPlaylistRecommendations(int count) async {
    return [];
  }

  Future<List<UnifiedRecommendation>> _getDiscoveryRecommendations(int count) async {
    return [];
  }

  Future<List<String>> _getRecentlyPlayed({int limit = 10}) async {
    final songs = await _db.getAllSongs();
    songs.sort((a, b) {
      final aTime = a.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return songs.take(limit).map((s) => s.id).toList();
  }

  Future<List<String>> _getNewReleases({int limit = 10}) async {
    final songs = await _db.getAllSongs();
    songs.sort((a, b) {
      final aTime = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return songs.take(limit).map((s) => s.id).toList();
  }

  List<UnifiedRecommendation> _deduplicate(List<UnifiedRecommendation> recs) {
    final seen = <String>{};
    return recs.where((r) => seen.add(r.trackId)).toList();
  }
}

class UnifiedRecommendation {
  final String trackId;
  final double score;
  final String source;
  final String reason;

  const UnifiedRecommendation({
    required this.trackId,
    required this.score,
    required this.source,
    required this.reason,
  });
}