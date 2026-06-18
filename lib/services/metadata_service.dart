import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/song_model.dart';
import '../core/constants.dart';
import 'database_service.dart';
import 'spotify_service.dart';
import 'ytmusic_service.dart';

class MetadataService {
  static final Set<String> _supportedExtensions =
      AppConstants.supportedAudioExtensions.toSet();

  static DatabaseService get _db => DatabaseService.instance;

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

      String? lyrics;
      try {
        lyrics = metadata.lyrics;
      } catch (_) {}

      return SongModel(
        id: id,
        title: metadata.title ?? nameWithoutExt,
        artist: metadata.artist ?? 'Unknown Artist',
        album: metadata.album ?? 'Unknown Album',
        duration: metadata.duration ?? Duration.zero,
        filePath: filePath,
        albumArt: albumArt,
        genre: metadata.genres.isNotEmpty ? metadata.genres.first : null,
        trackNumber: metadata.trackNumber,
        discNumber: metadata.discNumber,
        year: metadata.year?.year,
        bitrate: metadata.bitrate,
        fileSize: fileSize,
        lyrics: lyrics,
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

  static Future<int> backfillAlbumArt({
    SpotifyService? spotifyService,
    YTMusicService? ytMusicService,
  }) async {
    final tracks = await _db.getTracksMissingArt();
    int updated = 0;

    for (final track in tracks) {
      final trackId = track['id'] as String;
      final title = track['title'] as String? ?? '';
      final artist = track['artist'] as String? ?? '';
      final album = track['album'] as String? ?? '';

      String? imageUrl;

      if (spotifyService != null && spotifyService.isConnected) {
        final results = await spotifyService.searchTracks('$artist $title');
        if (results.isNotEmpty) {
          imageUrl = results.first.albumImageUrl;
        }
      }

      if (imageUrl == null && ytMusicService != null) {
        final results = await ytMusicService.search('$artist $title');
        if (results.isNotEmpty) {
          imageUrl = results.first.thumbnailUrl;
        }
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _db.updateTrackImageUrl(trackId, imageUrl);
        updated++;
      }
    }

    return updated;
  }

  static Future<int> backfillLyrics({
    YTMusicService? ytMusicService,
  }) async {
    final db = await _db.database;
    final tracks = await db.rawQuery('''
      SELECT s.id, s.title, s.artist FROM songs s
      WHERE (s.lyrics IS NULL OR s.lyrics = '')
      AND NOT EXISTS (SELECT 1 FROM track_lyrics tl WHERE tl.trackId = s.id)
    ''');
    int updated = 0;

    for (final track in tracks) {
      final trackId = track['id'] as String;
      final title = track['title'] as String? ?? '';
      final artist = track['artist'] as String? ?? '';

      if (ytMusicService != null) {
        final results = await ytMusicService.search('$artist $title');
        if (results.isNotEmpty) {
          final videoId = results.first.videoId;
          final playerData = await ytMusicService.client.player(videoId);
          if (playerData != null) {
            final captions = playerData['captions'] as Map<String, dynamic>?;
            final playerCaptionsTracklistRenderer = captions?['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
            final captionTracks = playerCaptionsTracklistRenderer?['captionTracks'] as List<dynamic>?;
            if (captionTracks != null && captionTracks.isNotEmpty) {
              for (final ct in captionTracks) {
                final baseUrl = (ct as Map<String, dynamic>)['baseUrl'] as String?;
                if (baseUrl != null) {
                  try {
                    final uri = Uri.parse('$baseUrl&fmt=srv3');
                    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
                    try {
                      final request = await client.getUrl(uri);
                      final response = await request.close();
                      if (response.statusCode == 200) {
                        final xml = await response.transform(utf8.decoder).join();
                        final lyrics = _parseTimedText(xml);
                        if (lyrics.isNotEmpty) {
                          await _db.saveLyrics(trackId, {
                            'lyrics': lyrics['plainText'],
                            'syncedLyrics': lyrics['syncedLrc'],
                            'source': 'ytmusic',
                          });
                          updated++;
                        }
                      }
                    } finally {
                      client.close();
                    }
                  } catch (_) {}
                  if (updated > 0) break;
                }
              }
            }
          }
        }
      }
    }

    return updated;
  }

  static Map<String, String> _parseTimedText(String xml) {
    final buffer = StringBuffer();
    final lrcLines = StringBuffer();
    final regExp = RegExp(r'<p t="(\d+)"[^>]*>(.*?)</p>');
    final matches = regExp.allMatches(xml);

    for (final match in matches) {
      final timeMs = int.tryParse(match.group(1) ?? '0') ?? 0;
      final text = match.group(2)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
      if (text.isEmpty) continue;
      final minutes = (timeMs ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((timeMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final millis = (timeMs % 1000).toString().padLeft(3, '0');
      lrcLines.writeln('[$minutes:$seconds.$millis]$text');
      buffer.writeln(text);
    }

    return {
      'plainText': buffer.toString().trim(),
      'syncedLrc': lrcLines.toString().trim(),
    };
  }

  static Future<int> backfillTrackMetadata({
    SpotifyService? spotifyService,
  }) async {
    final tracks = await _db.getTracksMissingMetadata();
    int updated = 0;

    for (final track in tracks) {
      final trackId = track['id'] as String;
      final title = track['title'] as String? ?? '';
      final artist = track['artist'] as String? ?? '';

      if (spotifyService != null && spotifyService.isConnected) {
        final results = await spotifyService.searchTracks('$artist $title');
        if (results.isNotEmpty) {
          final result = results.first;
          final updates = <String, dynamic>{};
          if (result.albumName != null && (track['album'] == 'Unknown Album' || track['album'] == null)) {
            updates['album'] = result.albumName;
          }
          if (result.artists.isNotEmpty && (track['artist'] == 'Unknown Artist' || track['artist'] == null)) {
            updates['artist'] = result.artists.join(', ');
          }
          if (result.durationMs > 0 && ((track['durationMs'] as int?) ?? 0) == 0) {
            updates['durationMs'] = result.durationMs;
          }
          if (updates.isNotEmpty) {
            await _db.updateTrackMetadata(trackId, updates);
            updated++;
          }
        }
      }
    }

    return updated;
  }

  static Future<String?> getHighResAlbumArt(String spotifyTrackId, {SpotifyService? spotifyService}) async {
    final cached = await _db.getHighResArtUrl(spotifyTrackId);
    if (cached != null) return cached;

    if (spotifyService == null || !spotifyService.isConnected) return null;

    final token = await spotifyService.getClientCredentialsToken();
    if (token == null) return null;

    try {
      final url = '${SpotifyAuthConfig.webApiBase}/tracks/$spotifyTrackId';
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set('Accept', 'application/json');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final album = data['album'] as Map<String, dynamic>?;
          final images = album?['images'] as List<dynamic>?;
          if (images != null && images.isNotEmpty) {
            String? bestUrl;
            int bestSize = 0;
            for (final img in images) {
              final w = (img as Map<String, dynamic>)['width'] as int? ?? 0;
              final h = img['height'] as int? ?? 0;
              final size = w * h;
              if (size > bestSize) {
                bestSize = size;
                bestUrl = img['url'] as String?;
              }
            }
            if (bestUrl != null) {
              await _db.saveHighResArtUrl(spotifyTrackId, bestUrl);
              return bestUrl;
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> getLyrics(String trackId) async {
    final cached = await _db.getLyrics(trackId);
    if (cached != null) {
      final lyrics = cached['lyrics'] as String?;
      if (lyrics != null && lyrics.isNotEmpty) return lyrics;
    }
    return null;
  }

  static Future<String?> getSyncedLyrics(String trackId) async {
    final cached = await _db.getLyrics(trackId);
    if (cached != null) {
      final synced = cached['syncedLyrics'] as String?;
      if (synced != null && synced.isNotEmpty) return synced;
    }
    return null;
  }

  static Map<String, dynamic> addMetadataToSong(Map<String, dynamic> song, {bool highResArt = false}) {
    final enriched = Map<String, dynamic>.from(song);
    if (highResArt && song['spotifyTrackId'] != null) {
      final trackId = song['spotifyTrackId'] as String;
      _db.getHighResArtUrl(trackId).then((url) {
        if (url != null) enriched['imageUrl'] = url;
      });
    }
    return enriched;
  }

  static Future<int> backfillAll({
    SpotifyService? spotifyService,
    YTMusicService? ytMusicService,
  }) async {
    int total = 0;
    total += await backfillAlbumArt(spotifyService: spotifyService, ytMusicService: ytMusicService);
    total += await backfillLyrics(ytMusicService: ytMusicService);
    total += await backfillTrackMetadata(spotifyService: spotifyService);
    return total;
  }
}
