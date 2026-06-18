import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class FileOrganizer {
  static final FileOrganizer _instance = FileOrganizer._();
  factory FileOrganizer() => _instance;
  FileOrganizer._();

  final DatabaseService _db = DatabaseService.instance;

  String _sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  Future<String> _getDownloadsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${dir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  Future<String> getOrganizedPath(String artist, String album, String filename) async {
    final baseDir = await _getDownloadsDir();
    final safeArtist = _sanitizeName(artist);
    final safeAlbum = _sanitizeName(album);
    return '$baseDir/$safeArtist/$safeAlbum/$filename';
  }

  Future<void> organizeDownloads({bool dryRun = false}) async {
    final dir = await _getDownloadsDir();
    final downloadsDir = Directory(dir);
    final files = downloadsDir.listSync().whereType<File>().toList();
    final reports = <Map<String, String>>[];

    for (final file in files) {
      final records = await _db.getFileRecords();
      final matched = records.where((r) => r['path'] == file.path).toList();
      if (matched.isNotEmpty) {
        final record = matched.first;
        final artist = record['artist'] as String;
        final album = record['album'] as String;
        final filename = record['filename'] as String;
        reports.add({'from': file.path, 'to': await getOrganizedPath(artist, album, filename)});
      }
    }

    if (dryRun) return;

    for (final report in reports) {
      await moveToOrganized(report['from']!, report['to']!);
    }
  }

  Future<void> moveToOrganized(String currentPath, String targetPath) async {
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);

    final original = File(currentPath);
    if (await original.exists()) {
      if (await targetFile.exists()) {
        final base = targetPath.replaceAll(RegExp(r'\.flac$'), '');
        var counter = 1;
        String newPath;
        do {
          newPath = '${base}_$counter.flac';
          counter++;
        } while (await File(newPath).exists());
        await original.rename(newPath);
      } else {
        await original.rename(targetPath);
      }

      await _db.setSetting('file_org_${currentPath.hashCode}', targetPath);
    }
  }

  Future<Map<String, Map<String, List<String>>>> getOrganizedStructure() async {
    final result = <String, Map<String, List<String>>>{};
    final records = await _db.getFileRecords();
    for (final record in records) {
      final artist = record['artist'] as String;
      final album = record['album'] as String;
      final filename = record['filename'] as String;
      result.putIfAbsent(artist, () => {});
      result[artist]!.putIfAbsent(album, () => []);
      result[artist]![album]!.add(filename);
    }
    return result;
  }

  Future<void> flattenStructure() async {
    final dir = await _getDownloadsDir();
    final baseDir = Directory(dir);

    final entries = baseDir.listSync(followLinks: false);
    for (final entry in entries) {
      if (entry is Directory) {
        await _flattenDirectory(entry, baseDir.path);
        try {
          await entry.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _flattenDirectory(Directory dir, String basePath) async {
    final entries = dir.listSync(followLinks: false);
    for (final entry in entries) {
      if (entry is File) {
        final filename = entry.path.split('/').last;
        final targetPath = '$basePath/$filename';
        final target = File(targetPath);
        if (await target.exists()) {
          final base = filename.replaceAll(RegExp(r'\.flac$'), '');
          var counter = 1;
          String newPath;
          do {
            newPath = '$basePath/${base}_$counter.flac';
            counter++;
          } while (await File(newPath).exists());
          await entry.rename(newPath);
        } else {
          await entry.rename(targetPath);
        }
      } else if (entry is Directory) {
        await _flattenDirectory(entry, basePath);
      }
    }
  }

  Future<List<String>> getArtistsInLibrary() async {
    final structure = await getOrganizedStructure();
    return structure.keys.toList()..sort();
  }

  Future<List<String>> getAlbumsForArtist(String artist) async {
    final structure = await getOrganizedStructure();
    final albums = structure[artist];
    if (albums == null) return [];
    return albums.keys.toList()..sort();
  }

  Future<bool> isOrganized() async {
    final dir = await _getDownloadsDir();
    final downloadsDir = Directory(dir);
    final entries = downloadsDir.listSync(followLinks: false);
    return entries.any((e) => e is Directory);
  }
}
