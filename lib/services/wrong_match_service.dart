import 'dart:convert';
import '../services/database_service.dart';
import '../services/ytmusic_service.dart';
import 'track_matcher.dart';

class WrongMatchService {
  final DatabaseService _db = DatabaseService.instance;
  final YTMusicService _ytmusic = YTMusicService();

  Future<void> flagWrongMatch(String spotifyTrackId, String ytVideoId) async {
    final existing = await _db.rawQuery(
      'SELECT * FROM wrong_matches WHERE spotifyTrackId = ? AND badYtVideoId = ? AND resolved = 0',
      [spotifyTrackId, ytVideoId],
    );
    if (existing.isNotEmpty) return;
    await _db.rawInsert('''
      INSERT INTO wrong_matches (spotifyTrackId, badYtVideoId, flaggedAt, resolved)
      VALUES (?, ?, ?, 0)
    ''', [spotifyTrackId, ytVideoId, DateTime.now().toIso8601String()]);
  }

  Future<List<YTMusicTrack>> getAlternatives(String title, String artist) async {
    final query = '$title ${artist.isNotEmpty ? artist : ''}'.trim();
    final results = await _ytmusic.search(query);
    results.sort((a, b) {
      final aScore = TrackMatcher.score(title, artist, a.title, a.artists);
      final bScore = TrackMatcher.score(title, artist, b.title, b.artists);
      return bScore.compareTo(aScore);
    });
    return results.take(10).toList();
  }

  Future<void> resolveAndUpdate(String spotifyTrackId, String newYtVideoId) async {
    await _db.rawUpdate(
      'UPDATE wrong_matches SET resolved = 1 WHERE spotifyTrackId = ?',
      [spotifyTrackId],
    );
    final existing = await _db.getSetting('spotify_matches');
    final matches = <String, String>{};
    if (existing != null && existing.isNotEmpty) {
      for (final entry in existing.split(',')) {
        final parts = entry.split('=');
        if (parts.length == 2) {
          matches[parts[0]] = parts[1];
        }
      }
    }
    matches[spotifyTrackId] = newYtVideoId;
    await _db.setSetting('spotify_matches', matches.entries
        .map((e) => '${e.key}=${e.value}')
        .join(','));
  }
}
