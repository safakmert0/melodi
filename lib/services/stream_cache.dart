import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';

class StreamCache {
  static const int defaultCacheLimit = 500 * 1024 * 1024;
  int _cacheLimit = defaultCacheLimit;

  int get cacheLimit => _cacheLimit;

  set cacheLimit(int limit) {
    _cacheLimit = limit;
  }

  Future<String> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'stream_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String> cacheStream(String url, String trackId) async {
    final cachePath = await _cacheDir;
    final localPath = p.join(
        cachePath, '${trackId}_${DateTime.now().millisecondsSinceEpoch}');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);

        final now = DateTime.now().toIso8601String();
        final db = DatabaseService.instance;
        await db.insertCacheEntry(
          trackId: trackId,
          url: url,
          localPath: localPath,
          size: response.bodyBytes.length,
          cachedAt: now,
          lastAccessedAt: now,
        );

        await _enforceCacheLimit();
        return localPath;
      }
    } catch (_) {}

    return '';
  }

  Future<String?> getCachedPath(String trackId) async {
    final db = DatabaseService.instance;
    final entry = await db.getCacheEntry(trackId);
    if (entry == null) return null;

    final localPath = entry['localPath'] as String?;
    if (localPath == null) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    await db.updateLastAccessed(trackId);
    return localPath;
  }

  Future<bool> isCached(String trackId) async {
    final path = await getCachedPath(trackId);
    return path != null;
  }

  Future<void> clearCache() async {
    final db = DatabaseService.instance;
    final entries = await db.getAllCacheEntries();
    for (final entry in entries) {
      final localPath = entry['localPath'] as String?;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await db.rawDelete('DELETE FROM stream_cache');
  }

  Future<int> getCacheSize() async {
    final db = DatabaseService.instance;
    return db.getTotalCacheSize();
  }

  Future<void> removeFromCache(String trackId) async {
    final db = DatabaseService.instance;
    final entry = await db.getCacheEntry(trackId);
    if (entry != null) {
      final localPath = entry['localPath'] as String?;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await db.removeCacheEntry(trackId);
  }

  Future<void> _enforceCacheLimit() async {
    final currentSize = await getCacheSize();
    if (currentSize <= _cacheLimit) return;

    final db = DatabaseService.instance;
    final entries = await db.getAllCacheEntries(orderBy: 'lastAccessedAt ASC');
    for (final entry in entries) {
      if (await getCacheSize() <= _cacheLimit) break;
      final trackId = entry['trackId'] as String;
      await removeFromCache(trackId);
    }
  }

  Future<void> evictLeastUsed() async {
    final db = DatabaseService.instance;
    final entries =
        await db.getAllCacheEntries(orderBy: 'lastAccessedAt ASC', limit: 1);
    if (entries.isNotEmpty) {
      final trackId = entries.first['trackId'] as String;
      await removeFromCache(trackId);
    }
  }
}
