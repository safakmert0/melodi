import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';

/// Çalma listesini M3U8 olarak dışa aktarır (yerel dosya yollarıyla)
/// ve sistem paylaşım sayfasını açar.
class PlaylistExporter {
  PlaylistExporter._();

  static String buildM3u(PlaylistModel playlist, List<SongModel> songs) {
    final buf = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#PLAYLIST:${_safeName(playlist.name)}');
    for (final s in songs) {
      final path = s.filePath;
      if (path.isEmpty) continue;
      final title = '${s.artist} - ${s.title}'.replaceAll('\n', ' ');
      final secs = s.duration.inSeconds;
      buf.writeln('#EXTINF:$secs,$title');
      buf.writeln(path);
    }
    return buf.toString();
  }

  static String _safeName(String input) {
    var s = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.length > 80) s = s.substring(0, 80).trim();
    return s.isEmpty ? 'liste' : s;
  }

  /// Dosyaya yazar, yolu döner (yoksa null).
  static Future<String?> writeM3u(
      PlaylistModel playlist, List<SongModel> songs) async {
    if (songs.isEmpty) return null;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/${_safeName(playlist.name)}.m3u8');
      await file.writeAsString(buildM3u(playlist, songs));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> shareM3u(
      PlaylistModel playlist, List<SongModel> songs) async {
    final path = await writeM3u(playlist, songs);
    if (path == null) return false;
    try {
      await Share.shareXFiles([XFile(path)],
          text: playlist.name, subject: playlist.name);
      return true;
    } catch (_) {
      return false;
    }
  }
}
