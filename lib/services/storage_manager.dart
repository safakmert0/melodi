import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'database_service.dart';

class StorageManager {
  static final StorageManager _instance = StorageManager._();
  factory StorageManager() => _instance;
  static StorageManager get instance => _instance;
  StorageManager._();

  final DatabaseService _db = DatabaseService.instance;
  static const MethodChannel _storageChannel =
      MethodChannel('com.melodi/storage');

  static const _audioExtensions = [
    'flac',
    'mp3',
    'm4a',
    'wav',
    'aac',
    'ogg',
    'wma',
    'alac',
    'aiff',
    'opus',
    'ape',
    'wv',
  ];

  static const _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
  ];

  Future<String> getStorageLocation() async {
    if (!Platform.isIOS) {
      final customPath = await _db.getSetting('download_path');
      if (customPath != null && customPath.isNotEmpty) return customPath;
      final documents = await getApplicationDocumentsDirectory();
      return p.join(documents.path, 'downloads');
    }
    // On iOS, use Documents directory so it's visible in Files app (UIFileSharingEnabled = true)
    final documents = await getApplicationDocumentsDirectory();
    final melodiDir = Directory(p.join(documents.path, 'Melodi', 'Offline'));
    await melodiDir.create(recursive: true);
    return melodiDir.path;
  }

  Future<Directory> _privateOfflineDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'Melodi', 'Offline'));
    await directory.create(recursive: true);
    if (Platform.isIOS) {
      try {
        await _storageChannel.invokeMethod<void>(
          'excludeFromBackup',
          {'path': directory.path},
        );
      } catch (_) {}
    }
    return directory;
  }

  /// Moves v4.1-and-older downloads out of Documents and repairs Spotify
  /// placeholders so a downloaded row opens the local file immediately.
  Future<({int moved, int relinked})> migrateLegacyDownloads() async {
    if (!Platform.isIOS) return (moved: 0, relinked: 0);
    final destination = await _privateOfflineDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final legacy = Directory(p.join(documents.path, 'downloads'));
    final oldMelodiDir = Directory(p.join(documents.path, 'Melodi'));
    var moved = 0;

    if (await legacy.exists()) {
      await for (final entity in legacy.list()) {
        if (entity is! File) continue;
        final extension =
            p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (!_audioExtensions.contains(extension)) continue;
        final oldPath = entity.path;
        final newPath =
            await _uniquePath(destination.path, p.basename(oldPath));
        try {
          await entity.rename(newPath);
        } catch (_) {
          await entity.copy(newPath);
          await entity.delete();
        }
        await _db.rawUpdate(
          'UPDATE songs SET filePath = ? WHERE filePath = ?',
          [newPath, oldPath],
        );
        await _db.rawUpdate(
          'UPDATE downloaded_tracks SET filePath = ? WHERE filePath = ?',
          [newPath, oldPath],
        );
        moved++;
      }
      try {
        if (await legacy.list().isEmpty) await legacy.delete();
      } catch (_) {}
    }

    var relinked = 0;
    final recordedDownloads = await _db.getDownloadedTracks();
    for (final record in recordedDownloads) {
      final sourceId = record['spotifyTrackId']?.toString();
      final localPath = record['filePath']?.toString();
      if (sourceId == null ||
          sourceId.isEmpty ||
          localPath == null ||
          localPath.isEmpty) {
        continue;
      }
      final file = File(localPath);
      if (!await file.exists()) continue;

      final placeholderId =
          sourceId.startsWith('spotify:') ? sourceId : 'spotify:$sourceId';
      final placeholder = await _db.getSongById(placeholderId);
      if (placeholder == null || placeholder.filePath == localPath) continue;
      await _db.insertSong(placeholder.copyWith(
        filePath: localPath,
        fileSize: await file.length(),
      ));
      relinked++;
    }

    final songs = await _db.getAllSongs();
    final localSongs = songs.where((song) {
      if (song.filePath.startsWith('spotify://') ||
          song.filePath.startsWith('youtube://') ||
          song.filePath.startsWith('http')) {
        return false;
      }
      return File(song.filePath).existsSync();
    }).toList();
    for (final placeholder
        in songs.where((song) => song.filePath.startsWith('spotify://'))) {
      final titleKey = _matchKey(placeholder.title);
      final artistKey = _matchKey(placeholder.artist.split(',').first);
      SongModel? match;
      for (final local in localSongs) {
        final pathKey = _matchKey(p.basenameWithoutExtension(local.filePath));
        final sameMetadata = _matchKey(local.title) == titleKey &&
            (_matchKey(local.artist).contains(artistKey) || artistKey.isEmpty);
        final fileNameMatch = titleKey.isNotEmpty &&
            pathKey.contains(titleKey) &&
            (artistKey.isEmpty || pathKey.contains(artistKey));
        if (sameMetadata || fileNameMatch) {
          match = local;
          break;
        }
      }
      if (match == null) continue;
      await _db.updateTrackMetadata(placeholder.id, {
        'filePath': match.filePath,
        'fileSize': File(match.filePath).lengthSync(),
      });
      relinked++;
    }
    await _db.setSetting('private_download_migration', 'completed');
    return (moved: moved, relinked: relinked);
  }

  Future<String> _uniquePath(String directory, String fileName) async {
    var candidate = p.join(directory, fileName);
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(
        directory,
        '${p.basenameWithoutExtension(fileName)} ($suffix)${p.extension(fileName)}',
      );
      suffix++;
    }
    return candidate;
  }

  String _matchKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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
    if (Platform.isIOS) {
      throw UnsupportedError('iOS downloads stay inside Melodi');
    }
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
    return files
        .take(limit)
        .map((f) => {
              'path': f.path,
              'name': f.path.split('/').last,
              'size': f.lengthSync(),
            })
        .toList();
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
