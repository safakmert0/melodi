import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'database_service.dart';

class ShareService {
  static ShareService? _instance;
  static ShareService get instance => _instance ??= ShareService._();
  ShareService._();

  final DatabaseService _db = DatabaseService.instance;

  Future<void> shareSong(SongModel song) async {
    final file = File(song.filePath);
    if (!await file.exists()) return;

    try {
      final dir = await getTemporaryDirectory();
      final shareDir = Directory('${dir.path}/share');
      if (!await shareDir.exists()) await shareDir.create();

      final ext = song.filePath.split('.').last;
      final shareFile = File('${shareDir.path}/${song.title}.$ext');
      await file.copy(shareFile.path);

      await Share.shareXFiles(
        [XFile(shareFile.path)],
        subject: '${song.title} - ${song.artist}',
      );
    } catch (e) {
      debugPrint('ShareService shareSong error: $e');
    }
  }

  Future<void> sharePlaylist(PlaylistModel playlist) async {
    try {
      final dir = await getTemporaryDirectory();
      final shareDir = Directory('${dir.path}/share_playlist');
      if (!await shareDir.exists()) await shareDir.create();

      final sharedFiles = <XFile>[];

      for (final songId in playlist.songIds) {
        final song = await _db.getSongById(songId);
        if (song == null) continue;

        final file = File(song.filePath);
        if (!await file.exists()) continue;

        final ext = song.filePath.split('.').last;
        final shareFile = File('${shareDir.path}/${song.title}.$ext');
        await file.copy(shareFile.path);
        sharedFiles.add(XFile(shareFile.path));
      }

      if (sharedFiles.isEmpty) return;

      await Share.shareXFiles(
        sharedFiles,
        subject: 'Playlist: ${playlist.name}',
      );
    } catch (e) {
      debugPrint('ShareService sharePlaylist error: $e');
    }
  }
}
