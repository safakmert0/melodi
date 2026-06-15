import 'dart:io';
import 'dart:typed_data';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../models/song_model.dart' as app;
import 'metadata_service.dart';
import 'database_service.dart';

enum ScanSource { mediaLibrary, filePicker, directory, all }

class MusicScannerService {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final DatabaseService _db = DatabaseService.instance;

  Future<bool> requestMediaLibraryPermission() async {
    final status = await Permission.mediaLibrary.request();
    return status.isGranted;
  }

  Future<PermissionStatus> checkPermission() async {
    if (Platform.isIOS) {
      return await Permission.mediaLibrary.status;
    }
    return await Permission.storage.status;
  }

  String? _getFilePath(dynamic raw) {
    try { return raw.filePath as String?; } catch (_) {}
    try { return raw.data as String?; } catch (_) {}
    try { return raw.uri as String?; } catch (_) {}
    return null;
  }

  int? _getTrackNumber(dynamic raw) {
    try { return raw.trackNumber as int?; } catch (_) {}
    return null;
  }

  int? _getDiscNumber(dynamic raw) {
    try { return raw.discNumber as int?; } catch (_) {}
    return null;
  }

  int? _getYear(dynamic raw) {
    try { return raw.year as int?; } catch (_) {}
    return null;
  }

  Future<List<app.SongModel>> scanMediaLibrary() async {
    final hasPermission = await requestMediaLibraryPermission();
    if (!hasPermission) return [];

    try {
      final rawSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final existingPaths = _db.getAllSongs().then((s) => s.map((e) => e.filePath).toSet());
      final paths = await existingPaths;

      final songs = <app.SongModel>[];
      for (final raw in rawSongs) {
        final filePath = _getFilePath(raw);
        if (filePath == null || filePath.isEmpty) continue;
        if (paths.contains(filePath)) continue;

        String title;
        try { title = raw.title ?? raw.displayName ?? 'Unknown'; } catch (_) { title = 'Unknown'; }
        String artist;
        try { artist = raw.artist ?? 'Unknown Artist'; } catch (_) { artist = 'Unknown Artist'; }
        String album;
        try { album = raw.album ?? 'Unknown Album'; } catch (_) { album = 'Unknown Album'; }
        int durationMs;
        try { durationMs = raw.duration ?? 0; } catch (_) { durationMs = 0; }
        int fileSize;
        try { fileSize = raw.size ?? 0; } catch (_) { fileSize = 0; }
        int idInt;
        try { idInt = raw.id as int; } catch (_) { idInt = 0; }

        Uint8List? artwork;
        try {
          final art = await _audioQuery.queryArtwork(
            idInt,
            ArtworkType.AUDIO,
            size: 500,
          );
          artwork = art;
        } catch (_) {}

        songs.add(app.SongModel(
          id: idInt.toString(),
          title: title,
          artist: artist,
          album: album,
          albumArtist: null,
          duration: Duration(milliseconds: durationMs),
          filePath: filePath,
          albumArt: artwork,
          genre: null,
          trackNumber: _getTrackNumber(raw),
          discNumber: _getDiscNumber(raw),
          year: _getYear(raw),
          fileSize: fileSize,
        ));
      }

      await _db.insertSongs(songs);
      return songs;
    } catch (e) {
      return [];
    }
  }

  Future<List<app.SongModel>> importFromFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: const [
          'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma',
          'alac', 'aiff', 'opus', 'ape', 'wv',
        ],
      );

      if (result == null || result.files.isEmpty) return [];

      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      var songs = await MetadataService.extractMultipleMetadata(paths);
      final existingPaths = await _db.getAllSongs().then((s) => s.map((e) => e.filePath).toSet());
      songs = songs.where((s) => !existingPaths.contains(s.filePath)).toList();
      await _db.insertSongs(songs);
      return songs;
    } catch (e) {
      return [];
    }
  }

  Future<List<app.SongModel>> importFromDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return [];

      return await importFromDirectoryPath(selectedDirectory);
    } catch (e) {
      return [];
    }
  }

  Future<List<app.SongModel>> importFromDirectoryPath(String directoryPath) async {
    try {
      var songs = await MetadataService.scanDirectory(directoryPath);
      final existingPaths = await _db.getAllSongs().then((s) => s.map((e) => e.filePath).toSet());
      songs = songs.where((s) => !existingPaths.contains(s.filePath)).toList();
      if (songs.isNotEmpty) {
        await _db.insertSongs(songs);
      }
      return songs;
    } catch (e) {
      return [];
    }
  }

  Future<List<app.SongModel>> scanAllSources() async {
    final allSongs = <app.SongModel>[];

    final librarySongs = await scanMediaLibrary();
    allSongs.addAll(librarySongs);

    return allSongs;
  }

  Future<List<app.SongModel>> scanDirectoryAndSync(String directoryPath) async {
    final scanned = await MetadataService.scanDirectory(directoryPath);
    final existing = await _db.getAllSongs();
    final existingPaths = existing.map((s) => s.filePath).toSet();
    final scannedPaths = scanned.map((s) => s.filePath).toSet();

    final newSongs = scanned.where((s) => !existingPaths.contains(s.filePath)).toList();
    if (newSongs.isNotEmpty) {
      await _db.insertSongs(newSongs);
    }

    // Only remove songs if the scan actually found files
    // (avoids deleting library when directory is temporarily inaccessible)
    if (scannedPaths.isNotEmpty) {
      final missingPaths = existingPaths.difference(scannedPaths);
      final toRemove = existing.where((s) => missingPaths.contains(s.filePath)).toList();
      for (final s in toRemove) {
        await _db.deleteSong(s.id);
      }
    }

    return newSongs;
  }

  Future<void> rescanLibrary() async {
    final songs = await scanAllSources();
    final validPaths = songs.map((s) => s.filePath).toSet();
    await _db.deleteSongsNotInPaths(validPaths);
  }

  Future<List<String>> getCommonMusicDirectories() async {
    final dirs = <String>[];
    if (Platform.isIOS) {
      final home = Platform.environment['HOME'] ?? '';
      final possibleDirs = [
        '$home/Music',
        '$home/iTunes',
        '$home/iTunes/Music',
        '/var/mobile/Media',
        '/private/var/mobile/Media',
      ];
      for (final d in possibleDirs) {
        if (await Directory(d).exists()) {
          dirs.add(d);
        }
      }
    }
    return dirs;
  }
}
