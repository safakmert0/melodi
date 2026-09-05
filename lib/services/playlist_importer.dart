import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/song_model.dart';
import 'backend_api_service.dart';
import 'multi_source_search.dart';
import 'platform_link_resolver.dart';

enum PlaylistImportSource {
  spotify,
  youtubeMusic,
  deezer,
  appleMusic,
  tidal,
  soundCloud,
  m3u,
  cue,
  unknown
}

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
    final u = url.toLowerCase().trim();
    if (u.endsWith('.m3u') || u.endsWith('.m3u8') || u.contains('.m3u?'))
      return PlaylistImportSource.m3u;
    if (u.endsWith('.cue')) return PlaylistImportSource.cue;
    if (u.endsWith('.pls')) return PlaylistImportSource.m3u;
    if (u.contains('spotify.com')) return PlaylistImportSource.spotify;
    if (u.contains('music.youtube.com') ||
        u.contains('youtube.com') ||
        u.contains('youtu.be')) {
      return PlaylistImportSource.youtubeMusic;
    }
    if (u.contains('deezer.com') || u.contains('dzr.cx'))
      return PlaylistImportSource.deezer;
    if (u.contains('music.apple.com') || u.contains('itunes.apple.com'))
      return PlaylistImportSource.appleMusic;
    if (u.contains('tidal.com') || u.contains('listen.tidal.com'))
      return PlaylistImportSource.tidal;
    if (u.contains('soundcloud.com')) return PlaylistImportSource.soundCloud;
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
      case PlaylistImportSource.appleMusic:
      case PlaylistImportSource.tidal:
      case PlaylistImportSource.soundCloud:
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        return seg.isNotEmpty ? seg.last : null;
      case PlaylistImportSource.m3u:
      case PlaylistImportSource.cue:
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
      case PlaylistImportSource.unknown:
        return null;
    }
  }

  static Future<PlaylistImportResult> import(String url) async {
    final source = detectSource(url);
    // Yerel dosya (Evermusic/Flacbox/Musix tarzı M3U/CUE/PLS)
    if (source == PlaylistImportSource.m3u ||
        source == PlaylistImportSource.cue) {
      if (url.startsWith('file://') ||
          await File(url).exists() ||
          url.contains('/')) {
        final path = url.replaceFirst('file://', '');
        final file = File(path);
        if (await file.exists()) {
          if (source == PlaylistImportSource.cue)
            return await _importCueFile(file);
          return await _importM3uFile(file);
        }
      }
    }
    final id = extractId(url, source);
    if (id == null) {
      // Bilinmeyen kaynakta akıllı fallback: MultiSourceSearch ile ara ve playlist yap
      if (source == PlaylistImportSource.unknown && url.trim().isNotEmpty) {
        return await _importViaSearch(url);
      }
      return PlaylistImportResult.error('Geçersiz çalma listesi bağlantısı.');
    }

    try {
      switch (source) {
        case PlaylistImportSource.youtubeMusic:
        case PlaylistImportSource.spotify:
          return await _importViaBackend(source, id, url);
        case PlaylistImportSource.deezer:
          return await _importDeezer(id);
        case PlaylistImportSource.appleMusic:
        case PlaylistImportSource.tidal:
        case PlaylistImportSource.soundCloud:
          return await _importViaSearch(url);
        case PlaylistImportSource.m3u:
        case PlaylistImportSource.cue:
          return PlaylistImportResult.error(
              'Yerel çalma listesi dosyası bulunamadı.');
        case PlaylistImportSource.unknown:
          return PlaylistImportResult.error(
              'Desteklenmeyen kaynak. Spotify, YouTube Music, Deezer, Apple Music, Tidal veya SoundCloud '
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

  // 8Spine/SpotiFLAC esintili: bilinmeyen URL'yi akıllı aramaya çevir
  static Future<PlaylistImportResult> _importViaSearch(String query) async {
    try {
      var searchQuery = query;
      if (query.startsWith('http://') || query.startsWith('https://')) {
        final resolved = await PlatformLinkResolver.resolve(query);
        final label = [resolved.artist, resolved.title]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(' - ');
        if (label.isNotEmpty) searchQuery = label;
      }
      final tracks = await MultiSourceSearch()
          .searchAllSync(searchQuery, limitPerSource: 5);
      if (tracks.isEmpty)
        return PlaylistImportResult.error('Arama sonucu bulunamadı.');
      final songs = tracks.take(20).map((t) {
        return _song('search_${query.hashCode}', t.id, t.title, t.artist,
            filePath: t.streamUrl ?? 'online://',
            album: t.album ?? '',
            duration: t.duration);
      }).toList();
      return PlaylistImportResult(
        source: PlaylistImportSource.unknown,
        songs: songs,
        playlistName: 'Arama: $query',
      );
    } catch (e) {
      return PlaylistImportResult.error('Arama içe aktarma başarısız: $e');
    }
  }

  // Evermusic/Flacbox/Musix esintili: yerel M3U/M3U8/PLS
  static Future<PlaylistImportResult> _importM3uFile(File file) async {
    try {
      final lines = await file.readAsLines();
      final songs = <SongModel>[];
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final isUrl = line.startsWith('http');
        if (isUrl) {
          // Uzak M3U satırı — online track olarak ekle
          songs.add(_song('m3u_${file.path.hashCode}', line.hashCode.toString(),
              line.split('/').last, 'Bilinmeyen',
              filePath: line));
        } else {
          // Yerel dosya yolu
          final f = File(line);
          if (!await f.exists()) continue;
          final name = line.split('/').last.split('.').first;
          songs.add(_song('m3u_${file.path.hashCode}', line.hashCode.toString(),
              name, 'Yerel',
              filePath: line));
        }
      }
      if (songs.isEmpty) return PlaylistImportResult.error('M3U dosyası boş.');
      return PlaylistImportResult(
          source: PlaylistImportSource.m3u,
          songs: songs,
          playlistName: file.uri.pathSegments.last);
    } catch (e) {
      return PlaylistImportResult.error('M3U okunamadı: $e');
    }
  }

  // Flacbox/Evermusic esintili: CUE sheet
  static Future<PlaylistImportResult> _importCueFile(File file) async {
    try {
      final content = await file.readAsString();
      final fileRegex = RegExp(r'FILE\s+"([^"]+)"', caseSensitive: false);
      final trackRegex = RegExp(r'TRACK\s+(\d+)\s+AUDIO', caseSensitive: false);
      final titleRegex = RegExp(r'TITLE\s+"([^"]+)"', caseSensitive: false);
      final performerRegex =
          RegExp(r'PERFORMER\s+"([^"]+)"', caseSensitive: false);
      final audioFile = fileRegex.firstMatch(content)?.group(1) ?? file.path;
      final tracks = trackRegex.allMatches(content).toList();
      final titles =
          titleRegex.allMatches(content).map((m) => m.group(1) ?? '').toList();
      final performers = performerRegex
          .allMatches(content)
          .map((m) => m.group(1) ?? '')
          .toList();
      final songs = <SongModel>[];
      for (var i = 0; i < tracks.length; i++) {
        final title = i < titles.length ? titles[i] : 'Parça ${i + 1}';
        final artist = i < performers.length ? performers[i] : 'Bilinmeyen';
        songs.add(_song('cue_${file.path.hashCode}', '${file.path.hashCode}_$i',
            title, artist,
            filePath: audioFile));
      }
      if (songs.isEmpty)
        return PlaylistImportResult.error('CUE dosyasında parça bulunamadı.');
      return PlaylistImportResult(
          source: PlaylistImportSource.cue,
          songs: songs,
          playlistName: file.uri.pathSegments.last);
    } catch (e) {
      return PlaylistImportResult.error('CUE okunamadı: $e');
    }
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
      PlaylistImportSource.appleMusic => 'Apple Music',
      PlaylistImportSource.tidal => 'Tidal',
      PlaylistImportSource.soundCloud => 'SoundCloud',
      PlaylistImportSource.m3u => 'M3U',
      PlaylistImportSource.cue => 'CUE',
      PlaylistImportSource.unknown => 'Çalma Listesi',
    };
    return '$label Çalma Listesi';
  }
}
