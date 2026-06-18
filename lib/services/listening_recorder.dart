import 'package:flutter/foundation.dart';
import 'database_service.dart';

class ListeningRecorder {
  static final ListeningRecorder instance = ListeningRecorder._();
  ListeningRecorder._();

  Future<void> recordPlayback(String trackId, String title, String artist,
      {String? album, String? source, int? durationMs}) async {
    final db = DatabaseService.instance;
    await db.insertListeningEvent({
      'trackId': trackId,
      'title': title,
      'artist': artist,
      'album': album ?? '',
      'source': source ?? '',
      'durationMs': durationMs ?? 0,
      'playedMs': 0,
      'isSkip': 0,
      'playedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> recordSkip(String trackId, String title, String artist,
      {int? playedMs}) async {
    final db = DatabaseService.instance;
    await db.insertListeningEvent({
      'trackId': trackId,
      'title': title,
      'artist': artist,
      'album': '',
      'source': '',
      'durationMs': 0,
      'playedMs': playedMs ?? 0,
      'isSkip': 1,
      'playedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getRecentPlays(int limit) async {
    final db = DatabaseService.instance;
    return db.getRecentPlays(limit);
  }

  Future<List<Map<String, dynamic>>> getTopArtists(int limit,
      {String period = 'all'}) async {
    final db = DatabaseService.instance;
    return db.getTopArtists(limit, period: period);
  }

  Future<List<Map<String, dynamic>>> getTopTracks(int limit,
      {String period = 'all'}) async {
    final db = DatabaseService.instance;
    return db.getTopTracks(limit, period: period);
  }

  Future<int> getPlayCountByTrack(String trackId) async {
    final db = DatabaseService.instance;
    return db.getPlayCountByTrack(trackId);
  }

  Future<int> getPlayCountByArtist(String artistName) async {
    final db = DatabaseService.instance;
    return db.getPlayCountByArtist(artistName);
  }

  Future<Map<String, dynamic>> getListeningStats() async {
    final db = DatabaseService.instance;
    return db.getListeningStats();
  }

  Future<List<Map<String, dynamic>>> getListeningHistoryByDate(
      DateTime date) async {
    final db = DatabaseService.instance;
    return db.getListeningHistoryByDate(date);
  }
}
