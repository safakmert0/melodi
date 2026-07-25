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

  Future<ShareResult> shareSong(SongModel song) async {
    final onlineText = _onlineShareText(song);
    if (onlineText != null) {
      return SharePlus.instance.share(
        ShareParams(
          text: onlineText,
          subject: '${song.title} — ${song.artist}',
        ),
      );
    }
    final file = File(song.filePath);
    if (!await file.exists()) {
      return SharePlus.instance.share(
        ShareParams(
          text: '🎵 ${song.title} — ${song.artist}\nMelodi',
          subject: '${song.title} — ${song.artist}',
        ),
      );
    }

    try {
      final dir = await getTemporaryDirectory();
      final shareDir = Directory('${dir.path}/share');
      if (!await shareDir.exists()) await shareDir.create();

      final ext = song.filePath.split('.').last;
      final shareFile = File('${shareDir.path}/${_safeName(song.title)}.$ext');
      await file.copy(shareFile.path);

      return SharePlus.instance.share(
        ShareParams(
          files: [XFile(shareFile.path)],
          subject: '${song.title} — ${song.artist}',
        ),
      );
    } catch (e) {
      debugPrint('ShareService shareSong error: $e');
      rethrow;
    }
  }

  String? _onlineShareText(SongModel song) {
    String? sourceUrl;
    if (song.filePath.startsWith('youtube://')) {
      final videoId = song.filePath.replaceFirst('youtube://', '');
      sourceUrl = 'https://music.youtube.com/watch?v=$videoId';
    } else if (song.filePath.startsWith('spotify://')) {
      final trackId = song.filePath.replaceFirst('spotify://', '');
      sourceUrl = 'https://open.spotify.com/track/$trackId';
    } else if (song.filePath.contains('youtube.com/watch') ||
        song.filePath.contains('youtu.be/')) {
      sourceUrl = song.filePath;
    } else if (song.filePath.startsWith('http://') ||
        song.filePath.startsWith('https://')) {
      // Signed CDN/media URLs expire and should not be exposed. Search tracks
      // retain their catalogue id, which is usually a YouTube video id.
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(song.id)) {
        sourceUrl = 'https://music.youtube.com/watch?v=${song.id}';
      }
    } else {
      return null;
    }
    return [
      '🎵 ${song.title} — ${song.artist}',
      if (sourceUrl != null) sourceUrl,
      'Melodi',
    ].join('\n');
  }

  String _safeName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  Future<ShareResult> sharePlaylist(PlaylistModel playlist) async {
    try {
      final dir = await getTemporaryDirectory();
      final shareDir = Directory('${dir.path}/share_playlist');
      if (!await shareDir.exists()) await shareDir.create();

      final sharedFiles = <XFile>[];

      for (final songId in playlist.songIds) {
        final song = await _db.getSongById(songId);
        if (song == null) continue;

        // Skip YouTube streaming tracks
        if (song.filePath.startsWith('youtube://') ||
            song.filePath.startsWith('http')) {
          continue;
        }
        final file = File(song.filePath);
        if (!await file.exists()) continue;

        final ext = song.filePath.split('.').last;
        final shareFile =
            File('${shareDir.path}/${_safeName(song.title)}.$ext');
        await file.copy(shareFile.path);
        sharedFiles.add(XFile(shareFile.path));
      }

      if (sharedFiles.isEmpty) {
        return SharePlus.instance.share(
          ShareParams(text: '🎶 ${playlist.name}\nMelodi'),
        );
      }

      return SharePlus.instance.share(
        ShareParams(
          files: sharedFiles,
          subject: 'Çalma listesi: ${playlist.name}',
        ),
      );
    } catch (e) {
      debugPrint('ShareService sharePlaylist error: $e');
      rethrow;
    }
  }
}
