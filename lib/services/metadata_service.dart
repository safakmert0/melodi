import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../core/constants.dart';
import 'database_service.dart';
import 'lyrics_service.dart';
import 'multi_source_search.dart';
import 'sources/youtube_music_source.dart';
import 'music_source.dart';
import 'musicbrainz_service.dart';

/// Result of a backfill run, including per-track failures so the UI can
/// surface exactly which tracks could not be completed and why.
class BackfillReport {
  final int updated;
  final int total;
  final List<String> failures;

  const BackfillReport({
    this.updated = 0,
    this.total = 0,
    this.failures = const [],
  });

  BackfillReport operator +(BackfillReport other) => BackfillReport(
        updated: updated + other.updated,
        total: total + other.total,
        failures: [...failures, ...other.failures],
      );
}

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
      if (metadata.pictures.isNotEmpty) {
        albumArt = metadata.pictures.first.bytes;
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

  static Future<BackfillReport> backfillAlbumArt({
    YouTubeMusicSource? ytmusicSource,
  }) async {
    final tracks = await _db.getTracksMissingArt();
    final failures = <String>[];
    int updated = 0;

    for (final track in tracks) {
      final trackId = track['id'] as String;
      final title = (track['title'] as String? ?? '').trim();
      final artist = (track['artist'] as String? ?? '').trim();
      if (title.isEmpty) {
        failures.add('$artist - <no title>: skipped (missing title)');
        continue;
      }

      String? url;
      String sourceLabel = 'unknown';
      try {
        // YouTube Music (no-auth search source).
        if (ytmusicSource != null) {
          final results =
              await ytmusicSource.search('$artist $title', limit: 5);
          final best = _bestOnlineCover(results, title, artist);
          if (best != null) {
            url = best.thumbnailUrl;
            sourceLabel = 'YouTube Music';
          }
        }

        // 3. Any other configured source as a last resort.
        if (url == null) {
          final other = await _searchCoverOtherSources(title, artist);
          if (other != null) {
            url = other.url;
            sourceLabel = other.source;
          }
        }

        if (url == null || url.isEmpty) {
          failures.add('$artist - $title: no matching cover in any source');
          continue;
        }

        final bytes = await _downloadBytes(url);
        if (bytes == null || bytes.isEmpty) {
          failures
              .add('$artist - $title: cover url unreachable ($sourceLabel)');
          continue;
        }

        // Persist the actual artwork bytes (what the UI renders) and keep the
        // remote URL for reference.
        await _db.updateTrackAlbumArt(trackId, bytes);
        await _db.updateTrackImageUrl(trackId, url);
        updated++;
      } catch (e) {
        failures.add('$artist - $title: $e');
      }
    }

    return BackfillReport(
        updated: updated, total: tracks.length, failures: failures);
  }

  static Future<BackfillReport> backfillLyrics({
    YouTubeMusicSource? ytmusicSource,
  }) async {
    final db = await _db.database;
    final tracks = await db.rawQuery('''
      SELECT s.id, s.title, s.artist, s.album, s.durationMs, s.filePath
      FROM songs s
      WHERE (s.lyrics IS NULL OR s.lyrics = '')
      AND NOT EXISTS (SELECT 1 FROM track_lyrics tl WHERE tl.trackId = s.id)
    ''');
    final failures = <String>[];
    int updated = 0;

    for (final track in tracks) {
      final trackId = track['id'] as String;
      final title = (track['title'] as String? ?? '').trim();
      final artist = (track['artist'] as String? ?? '').trim();
      final album = (track['album'] as String? ?? '').trim();
      final durationMs = (track['durationMs'] as int?) ?? 0;
      final filePath = track['filePath'] as String?;
      if (title.isEmpty) {
        failures.add('$artist - <no title>: skipped (missing title)');
        continue;
      }

      try {
        final result = await LyricsService.fetchLyrics(
          artist: artist,
          track: title,
          album: album.isNotEmpty ? album : null,
          durationMs: durationMs > 0 ? durationMs : null,
          filePath: filePath,
          preferSynced: true,
        );

        if (result == null ||
            (result.plainText == null && result.syncedLrc == null)) {
          failures.add('$artist - $title: no lyrics found');
          continue;
        }

        final plain = result.plainText ?? result.syncedLrc;
        final synced = result.syncedLrc;
        await _db.saveLyrics(trackId, {
          'lyrics': plain,
          'syncedLyrics': synced,
          'source': result.source ?? 'lrclib',
        });
        if (plain != null && plain.isNotEmpty) {
          await _db.updateTrackMetadata(trackId, {'lyrics': plain});
        }
        updated++;
      } catch (e) {
        failures.add('$artist - $title: $e');
      }
    }

    return BackfillReport(
        updated: updated, total: tracks.length, failures: failures);
  }

  // --- cover-art helpers -------------------------------------------------

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f\u0400-\u04ff]+'), ' ')
      .trim();

  /// Score how well a candidate matches the wanted title/artist.
  /// >= 3 means at least a partial title match; >= 5 means exact title match.
  static int _scoreMatch(String wantedTitle, String wantedArtist,
      String candTitle, String candArtist) {
    final wt = _normalize(wantedTitle);
    final wa = _normalize(wantedArtist.split(',').first);
    final ct = _normalize(candTitle);
    final ca = _normalize(candArtist);
    var score = 0;
    if (ct == wt) {
      score += 5;
    } else if (ct.contains(wt) || wt.contains(ct)) {
      score += 3;
    }
    if (wa.isNotEmpty && ca.contains(wa)) score += 3;
    return score;
  }

  static OnlineTrack? _bestOnlineCover(
      List<OnlineTrack> items, String title, String artist) {
    OnlineTrack? best;
    var bestScore = 0;
    for (final it in items) {
      final score = _scoreMatch(title, artist, it.title, it.artist);
      if (score > bestScore &&
          it.thumbnailUrl != null &&
          it.thumbnailUrl!.isNotEmpty) {
        bestScore = score;
        best = it;
      }
    }
    return bestScore >= 3 ? best : null;
  }

  static Future<_CoverCandidate?> _searchCoverOtherSources(
      String title, String artist) async {
    try {
      final all = await MultiSourceSearch()
          .searchAllSync('$artist $title', limitPerSource: 5);
      final best = _bestOnlineCover(all, title, artist);
      if (best != null &&
          best.thumbnailUrl != null &&
          best.thumbnailUrl!.isNotEmpty) {
        return _CoverCandidate(best.thumbnailUrl!, best.sourceLabel);
      }
    } catch (e) {
      debugPrint('backfill album art (other sources) error: $e');
    }
    return null;
  }

  static Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent', 'Melodi/1.0');
        final response = await request.close();
        if (response.statusCode == 200) {
          return await consolidateHttpClientResponseBytes(response);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('backfill album art download error: $e');
    }
    return null;
  }

  static Map<String, String> _parseTimedText(String xml) {
    final buffer = StringBuffer();
    final lrcLines = StringBuffer();
    final regExp = RegExp(r'<p t="(\d+)"[^>]*>(.*?)</p>');

    final matches = regExp.allMatches(xml);

    for (final match in matches) {
      final timeMs = int.tryParse(match.group(1) ?? '0') ?? 0;
      final text =
          match.group(2)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
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

  static Future<BackfillReport> backfillTrackMetadata() async {
    final db = await _db.database;
    final tracks = await db.query('songs',
        columns: ['id', 'title', 'artist', 'album', 'genre', 'year']);
    var updated = 0;
    final failures = <String>[];
    for (final row in tracks) {
      final title = (row['title'] as String? ?? '').trim();
      final artist = (row['artist'] as String? ?? '').trim();
      if (title.isEmpty || artist.isEmpty) continue;
      if ((row['genre'] as String? ?? '').isNotEmpty && row['year'] != null) {
        continue;
      }
      try {
        final match = await MusicBrainzService.findRecording(
          title: title,
          artist: artist,
          album: row['album'] as String?,
        );
        if (match == null) {
          failures.add('$artist - $title: MusicBrainz eşleşmesi yok');
          continue;
        }
        final changes = <String, dynamic>{};
        if ((row['genre'] as String? ?? '').isEmpty && match.genre != null) {
          changes['genre'] = match.genre;
        }
        if (row['year'] == null && match.year != null)
          changes['year'] = match.year;
        if ((row['album'] as String? ?? '').isEmpty && match.album != null) {
          changes['album'] = match.album;
        }
        if (changes.isNotEmpty) {
          await _db.updateTrackMetadata(row['id'] as String, changes);
          updated++;
        }
      } catch (error) {
        failures.add('$artist - $title: $error');
      }
    }
    return BackfillReport(
        updated: updated, total: tracks.length, failures: failures);
  }

  static Future<String?> getHighResAlbumArt(String spotifyTrackId) async {
    // High-resolution artwork was sourced from Spotify; that integration has
    // been removed. Return any previously cached URL, otherwise null.
    return _db.getHighResArtUrl(spotifyTrackId);
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

  static Future<Map<String, dynamic>> addMetadataToSong(
      Map<String, dynamic> song,
      {bool highResArt = false}) async {
    final enriched = Map<String, dynamic>.from(song);
    if (highResArt && song['spotifyTrackId'] != null) {
      final trackId = song['spotifyTrackId'] as String;
      final url = await _db.getHighResArtUrl(trackId);
      if (url != null) enriched['imageUrl'] = url;
    }
    return enriched;
  }

  static Future<BackfillReport> backfillAll({
    YouTubeMusicSource? ytmusicSource,
  }) async {
    final art = await backfillAlbumArt(ytmusicSource: ytmusicSource);
    final lyrics = await backfillLyrics(ytmusicSource: ytmusicSource);
    final meta = await backfillTrackMetadata();
    return art + lyrics + meta;
  }
}

class _CoverCandidate {
  final String url;
  final String source;
  const _CoverCandidate(this.url, this.source);
}
