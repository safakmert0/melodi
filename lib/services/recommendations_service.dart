import 'package:melodi/services/database_service.dart';
import 'package:melodi/models/song_model.dart';

class RecommendationsService {
  static RecommendationsService? _instance;
  final DatabaseService _databaseService;

  RecommendationsService._(this._databaseService);

  static RecommendationsService get instance {
    _instance ??= RecommendationsService._(DatabaseService.instance);
    return _instance!;
  }

  Future<List<SongModel>> getRecommendations({int limit = 20}) async {
    final allSongs = await _databaseService.getAllSongs();
    if (allSongs.isEmpty) return [];

    final recentPlays = await _getRecentlyPlayedSongs(limit: 10);
    final favoriteGenres = _analyzeFavoriteGenres(allSongs);
    final recentArtists = _getRecentlyPlayedArtists(recentPlays);

    final scored = allSongs.map((song) {
      double score = 0;

      score += song.playCount * 2;

      if (song.lastPlayed != null) {
        final hoursSincePlayed = DateTime.now()
            .difference(song.lastPlayed!)
            .inHours;
        if (hoursSincePlayed < 24) {
          score += 10;
        } else if (hoursSincePlayed < 168) {
          score += 5;
        }
      }

      if (song.genre != null && favoriteGenres.contains(song.genre)) {
        score += 15;
      }

      if (recentArtists.contains(song.artist)) {
        score += 20;
      }

      if (song.isFavorite) {
        score += 8;
      }

      final hour = DateTime.now().hour;
      if (_isTimeOfDayMatch(hour, song.genre)) {
        score += 3;
      }

      return MapEntry(song, score);
    });

    scored.sort((a, b) => b.value.compareTo(a.value));
    final recommended = scored.map((e) => e.key).take(limit).toList();
    return recommended;
  }

  Future<List<SongModel>> getRecentlyPlayed({int limit = 20}) async {
    return _getRecentlyPlayedSongs(limit: limit);
  }

  Future<List<SongModel>> getMostPlayed({int limit = 20}) async {
    return _databaseService.getMostPlayedSongs(limit: limit);
  }

  Future<List<SongModel>> _getRecentlyPlayedSongs({int limit = 20}) async {
    return _databaseService.getRecentSongs(limit: limit);
  }

  List<String> _getRecentlyPlayedArtists(List<SongModel> recentSongs) {
    final artists = <String>{};
    for (final song in recentSongs) {
      artists.add(song.artist);
    }
    return artists.toList();
  }

  Set<String> _analyzeFavoriteGenres(List<SongModel> allSongs) {
    final genreCounts = <String, int>{};
    for (final song in allSongs) {
      if (song.genre != null) {
        genreCounts[song.genre!] = (genreCounts[song.genre!] ?? 0) + song.playCount;
      }
    }

    final sortedGenres = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedGenres.take(3).map((e) => e.key).toSet();
  }

  bool _isTimeOfDayMatch(int hour, String? genre) {
    if (genre == null) return false;

    final genreLower = genre.toLowerCase();

    if (hour >= 6 && hour < 12) {
      return genreLower.contains('pop') || genreLower.contains('indie');
    } else if (hour >= 12 && hour < 18) {
      return genreLower.contains('rock') || genreLower.contains('alternative');
    } else if (hour >= 18 && hour < 22) {
      return genreLower.contains('electronic') || genreLower.contains('dance');
    } else {
      return genreLower.contains('jazz') || genreLower.contains('classical') || genreLower.contains('ambient');
    }
  }
}