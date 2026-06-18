import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class StorageManager {
  static final StorageManager _instance = StorageManager._();
  factory StorageManager() => _instance;
  static StorageManager get instance => _instance;
  StorageManager._();

  final DatabaseService _db = DatabaseService.instance;

  static const _audioExtensions = [
    'flac', 'mp3', 'm4a', 'wav', 'aac', 'ogg', 'wma',
    'alac', 'aiff', 'opus', 'ape', 'wv',
  ];

  static const _imageExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'bmp',
  ];

  Future<String> getStorageLocation() async {
    final customPath = await _db.getSetting('download_path');
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/downloads';
  }

  Future<int> getLibrarySize() async {
    final dir = Directory(await getStorageLocation());
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<Map<String, int>> getStorageUsage() async {
    final dir = Directory(await getStorageLocation());
    if (!await dir.exists()) return {'audio': 0, 'art': 0, 'other': 0};
    int audio = 0, art = 0, other = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final size = await entity.length();
        final ext = entity.path.split('.').last.toLowerCase();
        if (_audioExtensions.contains(ext)) {
          audio += size;
        } else if (_imageExtensions.contains(ext)) {
          art += size;
        } else {
          other += size;
        }
      }
    }
    return {'audio': audio, 'art': art, 'other': other};
  }

  Future<int> getFileCount() async {
    final dir = Directory(await getStorageLocation());
    if (!await dir.exists()) return 0;
    int count = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) count++;
    }
    return count;
  }

  Future<void> clearCache() async {
    final dir = Directory(await getStorageLocation());
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (!_audioExtensions.contains(ext)) {
          await entity.delete();
        }
      }
    }
  }

  Future<void> moveLibrary(String newPath,
      {void Function(double progress)? onProgress}) async {
    final source = Directory(await getStorageLocation());
    if (!await source.exists()) return;
    final dest = Directory(newPath);
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }
    final entries = await source.list().toList();
    for (int i = 0; i < entries.length; i++) {
      final entity = entries[i];
      if (entity is File) {
        final name = entity.path.split('/').last;
        await entity.copy('${dest.path}/$name');
        await entity.delete();
      }
      onProgress?.call((i + 1) / entries.length);
    }
    await _db.setSetting('download_path', newPath);
  }

  Future<List<Map<String, dynamic>>> getLargestFiles(int limit) async {
    final dir = Directory(await getStorageLocation());
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) files.add(entity);
    }
    files.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    return files.take(limit).map((f) => {
      'path': f.path,
      'name': f.path.split('/').last,
      'size': f.lengthSync(),
    }).toList();
  }

  Future<Map<String, Map<String, int>>> getFormatBreakdown() async {
    final dir = Directory(await getStorageLocation());
    if (!await dir.exists()) return {};
    final counts = <String, int>{};
    final sizes = <String, int>{};
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        counts[ext] = (counts[ext] ?? 0) + 1;
        sizes[ext] = (sizes[ext] ?? 0) + await entity.length();
      }
    }
    final result = <String, Map<String, int>>{};
    for (final key in counts.keys) {
      result[key] = {'count': counts[key]!, 'size': sizes[key]!};
    }
    return result;
  }
}
