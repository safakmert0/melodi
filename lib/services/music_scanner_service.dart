import 'dart:io';
import 'dart:typed_data';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<List<app.SongModel>> scanMediaLibrary() async {
    final hasPermission = await requestMediaLibraryPermission();
    if (!hasPermission) return [];

    try {
      final rawSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final songs = <app.SongModel>[];
      for (final raw in rawSongs) {
        if (raw.title == null || raw.title!.isEmpty) continue;

        Uint8List? artwork;
        try {
          final art = await _audioQuery.queryArtwork(
            raw.id,
            ArtworkType.AUDIO,
            size: 500,
          );
          artwork = art;
        } catch (_) {}

        songs.add(app.SongModel(
          id: raw.id.toString(),
          title: raw.title ?? raw.displayName ?? 'Unknown',
          artist: raw.artist ?? 'Unknown Artist',
          album: raw.album ?? 'Unknown Album',
          albumArtist: null,
          duration: Duration(milliseconds: raw.duration ?? 0),
          filePath: raw.data ?? '',
          albumArt: artwork,
          genre: null,
          trackNumber: null,
          discNumber: null,
          year: null,
          fileSize: raw.size ?? 0,
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

      final songs = await MetadataService.extractMultipleMetadata(paths);
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

      final songs =
          await MetadataService.scanDirectory(selectedDirectory);
      await _db.insertSongs(songs);
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

  Future<void> rescanLibrary() async {
    final songs = await scanAllSources();
    final validPaths = songs.map((s) => s.filePath).toSet();
    await _db.deleteSongsNotInPaths(validPaths);
  }

  Future<List<String>> getCommonMusicDirectories() async {
    final dirs = <String>[];
    if (Platform.isIOS) {
      final home = await getApplicationDocumentsDirectory();
      final possibleDirs = [
        '${home.path}/Music',
        '${home.parent.path}/iTunes',
        '${home.parent.path}/iTunes/Music',
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
