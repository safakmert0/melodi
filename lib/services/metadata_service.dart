import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/song_model.dart';
import '../core/constants.dart';

class MetadataService {
  static final Set<String> _supportedExtensions =
      AppConstants.supportedAudioExtensions.toSet();

  static bool isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _supportedExtensions.contains(ext);
  }

  static Future<SongModel?> extractMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileSize = await file.length();
      final fileName = filePath.split('/').last;
      final nameWithoutExt = fileName.split('.').first;

      final metadata = readMetadata(file, getImage: true);

      final id = '$filePath|${DateTime.now().millisecondsSinceEpoch}';

      Uint8List? albumArt;
      if (metadata.pictures != null && metadata.pictures!.isNotEmpty) {
        albumArt = metadata.pictures!.first.bytes;
      }

      return SongModel(
        id: id,
        title: metadata.title ?? nameWithoutExt,
        artist: metadata.artist ?? 'Unknown Artist',
        album: metadata.album ?? 'Unknown Album',
        albumArtist: metadata.albumArtist,
        duration: Duration(
            milliseconds: metadata.durationMs?.toInt() ?? 0),
        filePath: filePath,
        albumArt: albumArt,
        genre: metadata.genre,
        trackNumber: metadata.trackNumber,
        discNumber: metadata.discNumber,
        year: metadata.year,
        bitrate: metadata.bitrate?.toInt(),
        fileSize: fileSize,
      );
    } catch (e) {
      return _createFallbackMetadata(filePath);
    }
  }

  static Future<SongModel> _createFallbackMetadata(String filePath) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final fileName = filePath.split('/').last;
    final nameWithoutExt = fileName.split('.').first;

    return SongModel(
      id: filePath,
      title: nameWithoutExt,
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      duration: Duration.zero,
      filePath: filePath,
      fileSize: fileSize,
    );
  }

  static Future<List<SongModel>> scanDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final files = <SongModel>[];
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && isAudioFile(entity.path)) {
          final song = await extractMetadata(entity.path);
          if (song != null) {
            files.add(song);
          }
        }
      }
    } catch (_) {}

    return files;
  }

  static Future<List<SongModel>> scanDirectories(List<String> paths) async {
    final allSongs = <SongModel>[];
    for (final path in paths) {
      final songs = await scanDirectory(path);
      allSongs.addAll(songs);
    }
    return allSongs;
  }

  static Future<List<SongModel>> extractMultipleMetadata(
      List<String> paths) async {
    final songs = <SongModel>[];
    for (final path in paths) {
      if (isAudioFile(path)) {
        final song = await extractMetadata(path);
        if (song != null) {
          songs.add(song);
        }
      }
    }
    return songs;
  }

  static Set<String> findAudioFilesInDirectory(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return {};

    final files = <String>{};
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && isAudioFile(entity.path)) {
          files.add(entity.path);
        }
      }
    } catch (_) {}
    return files;
  }
}
