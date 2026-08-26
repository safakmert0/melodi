import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/song_model.dart';
import 'backend_api_service.dart';

enum PlaylistImportSource { spotify, youtubeMusic, deezer, unknown }

class PlaylistImportResult {
  PlaylistImportResult({
    this.source = PlaylistImportSource.unknown,
    this.songs = const [],
    this.playlistName,
    this.error,
  });

  factory PlaylistImportResult.error(String message) =>
      PlaylistImportResult(error: message);

  final PlaylistImportSource source;
  final List<SongModel> songs;
  final String? playlistName;
  final String? error;

  bool get isError => error != null;
}

class PlaylistImporter {
  PlaylistImporter._();

  static PlaylistImportSource detectSource(String url) {
    final u = url.toLowerCase();
    if (u.contains('spotify.com')) return PlaylistImportSource.spotify;
    if (u.contains('music.youtube.com') ||
        u.contains('youtube.com') ||
        u.contains('youtu.be')) {
      return PlaylistImportSource.youtubeMusic;
    }
    if (u.contains('deezer.com') || u.contains('dzr.cx')) {
      return PlaylistImportSource.deezer;
    }
    return PlaylistImportSource.unknown;
  }

  static String? extractId(String url, PlaylistImportSource source) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    switch (source) {
      case PlaylistImportSource.spotify:
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        return seg.isNotEmpty ? seg.last : null;
      case PlaylistImportSource.youtubeMusic:
        return uri.queryParameters['list'];
      case PlaylistImportSource.deezer:
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (seg.length >= 2 && seg[seg.length - 2] == 'playlist') {
          return seg.last;
        }
        return seg.isNotEmpty ? seg.last : null;
      case PlaylistImportSource.unknown:
        return null;
    }
  }

  static Future<PlaylistImportResult> import(String url) async {
    final source = detectSource(url);
    final id = extractId(url, source);
    if (id == null) {
      return PlaylistImportResult.error('Geçersiz çalma listesi bağlantısı.');
    }

    try {
      switch (source) {
        case PlaylistImportSource.youtubeMusic:
        case PlaylistImportSource.spotify:
          return await _importViaBackend(source, id, url);
        case PlaylistImportSource.deezer:
          return await _importDeezer(id);
        case PlaylistImportSource.unknown:
          return PlaylistImportResult.error(
              'Desteklenmeyen kaynak. Spotify, YouTube Music veya Deezer '
              'çalma listesi bağlantısı yapıştırın.');
      }
    } catch (e) {
      return PlaylistImportResult.error('Çalma listesi alınamadı: $e');
    }
  }

  static Future<PlaylistImportResult> _importViaBackend(
    PlaylistImportSource source,
    String id,
    String url,
  ) async {
    final videos = await BackendApiService.instance.getPlaylist(id);
    if (videos.isEmpty) {
      return PlaylistImportResult.error(
          'Bu çalma listesi boş veya sunucuya ulaşılamadı. YT-DLP backend '
          'ayarlarını kontrol edin.');
    }
    final songs = videos.map((v) {
      return _song('${source.name}_$id', v.id, v.title, v.author,
          filePath: 'youtube:${v.id}');
    }).toList();
    return PlaylistImportResult(
      source: source,
      songs: songs,
      playlistName: _defaultName(source, id),
    );
  }

  static Future<PlaylistImportResult> _importDeezer(String id) async {
    final response = await http
        .get(Uri.parse('https://api.deezer.com/playlist/$id'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      return PlaylistImportResult.error('Deezer çalma listesine ulaşılamadı.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final name = data['title'] as String?;
    final tracks = (data['tracks']?['data'] as List?) ?? [];
    if (tracks.isEmpty) {
      return PlaylistImportResult.error('Bu Deezer çalma listesi boş.');
    }
    final songs = tracks.map((t) {
      final title = (t['title'] as String?) ?? '';
      final artist = (t['artist']?['name'] as String?) ?? '';
      final album = (t['album']?['title'] as String?) ?? '';
      final duration = Duration(seconds: (t['duration'] as int?) ?? 0);
      return _song('deezer_$id', '$id-${t['id']}', title, artist,
          filePath: 'online://', album: album, duration: duration);
    }).toList();
    return PlaylistImportResult(
      source: PlaylistImportSource.deezer,
      songs: songs,
      playlistName: name ?? _defaultName(PlaylistImportSource.deezer, id),
    );
  }

  static SongModel _song(
    String baseId,
    String trackId,
    String title,
    String artist, {
    required String filePath,
    String album = '',
    Duration duration = Duration.zero,
  }) {
    return SongModel(
      id: 'imp_${baseId}_$trackId',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      filePath: filePath,
      fileSize: 0,
    );
  }

  static String _defaultName(PlaylistImportSource source, String id) {
    final label = switch (source) {
      PlaylistImportSource.spotify => 'Spotify',
      PlaylistImportSource.youtubeMusic => 'YouTube Music',
      PlaylistImportSource.deezer => 'Deezer',
      PlaylistImportSource.unknown => 'Çalma Listesi',
    };
    return '$label Çalma Listesi';
  }
}
