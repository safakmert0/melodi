import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class MixService {
  final Random _random = Random();

  MixService();

  Future<List<Map<String, dynamic>>> getDailyMix() async {
    try {
      final cached = await _getCachedMix('daily_mix');
      if (cached != null) return cached;

      final local = await _generateLocalMix('daily', 20);
      if (local.isNotEmpty) {
        await _cacheMix('daily_mix', local);
      }
      return local;
    } catch (e) {
      debugPrint('getDailyMix failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReleaseRadar() async {
    try {
      final cached = await _getCachedMix('release_radar');
      if (cached != null) return cached;

      final local = await _generateLocalMix('release', 15);
      if (local.isNotEmpty) {
        await _cacheMix('release_radar', local);
      }
      return local;
    } catch (e) {
      debugPrint('getReleaseRadar failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDiscoverWeekly() async {
    try {
      final cached = await _getCachedMix('discover_weekly');
      if (cached != null) return cached;

      final local = await _generateLocalMix('discover', 20);
      if (local.isNotEmpty) {
        await _cacheMix('discover_weekly', local);
      }
      return local;
    } catch (e) {
      debugPrint('getDiscoverWeekly failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _generateLocalMix(
      String mixType, int count) async {
    final db = DatabaseService.instance;
    final allSongs = await db.getAllSongs();
    if (allSongs.isEmpty) return [];

    final shuffled = List.of(allSongs)..shuffle(_random);
    final selected = shuffled.take(min(count, shuffled.length));

    return selected
        .map((s) => <String, dynamic>{
              'id': s.id,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'imageUrl': null,
              'albumArt': s.albumArt,
              'durationMs': s.duration.inMilliseconds,
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTasteMatch(String userId) async {
    final db = DatabaseService.instance;
    final allSongs = await db.getAllSongs();
    if (allSongs.isEmpty) return [];
    final shuffled = List.of(allSongs)..shuffle(_random);
    return shuffled
        .take(10)
        .map((s) => <String, dynamic>{
              'id': s.id,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'imageUrl': null,
              'albumArt': s.albumArt,
              'durationMs': s.duration.inMilliseconds,
            })
        .toList();
  }

  Future<void> _cacheMix(
      String mixType, List<Map<String, dynamic>> data) async {
    final db = DatabaseService.instance;
    await db.cacheMix(mixType, jsonEncode(data));
  }

  Future<List<Map<String, dynamic>>?> _getCachedMix(String mixType) async {
    final db = DatabaseService.instance;
    final cached = await db.getCachedMix(mixType);
    if (cached == null) return null;

    final generatedAt = cached['generatedAt'];
    if (generatedAt == null) return null;

    final generated = DateTime.parse(generatedAt);
    if (DateTime.now().difference(generated).inHours >= 24) return null;

    final dataStr = cached['data'];
    if (dataStr == null) return null;

    final decoded = jsonDecode(dataStr) as List<dynamic>;
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }
}
