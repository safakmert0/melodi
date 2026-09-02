import 'package:melodi/core/errors.dart';
import 'package:melodi/data/datasources/local/db_service.dart';
import 'package:melodi/data/datasources/native/melodi_core.dart';
import 'package:melodi/data/models/song.dart';

class SongRepository {
  final DbService _db;
  final MelodiCore _melodiCore;

  SongRepository({
    required DbService db,
    required MelodiCore melodiCore,
  })  : _db = db,
        _melodiCore = melodiCore;

  static const String _tableName = 'songs';

  Future<Result<List<Song>>> getAll({
    int? limit,
    int? offset,
    String? query,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      final db = await _db.database;
      String sql = 'SELECT * FROM $_tableName';
      final args = <Object>[];

      if (query != null && query.isNotEmpty) {
        sql += ' WHERE title LIKE ? OR artist LIKE ? OR album LIKE ?';
        final searchTerm = '%$query%';
        args.addAll([searchTerm, searchTerm, searchTerm]);
      }

      sql += ' ORDER BY ${sortBy ?? 'title'} ${ascending ? 'ASC' : 'DESC'}';

      if (limit != null) {
        sql += ' LIMIT ?';
        args.add(limit);
      }
      if (offset != null) {
        sql += ' OFFSET ?';
        args.add(offset);
      }

      final rows = await db.rawQuery(sql, args);
      return Result.success(rows.map(_songFromRow).toList());
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get songs: $e', st));
    }
  }

  Future<Result<Song?>> getById(String id) async {
    try {
      final db = await _db.database;
      final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return const Result.success(null);
      return Result.success(_songFromRow(rows.first));
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get song: $e', st));
    }
  }

  Future<Result<Song>> insert(Song song) async {
    try {
      final db = await _db.database;
      await db.insert(_tableName, _songToMap(song), conflictAlgorithm: ConflictAlgorithm.replace);
      return Result.success(song);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to insert song: $e', st));
    }
  }

  Future<Result<void>> insertAll(List<Song> songs) async {
    try {
      final db = await _db.database;
      final batch = db.batch();
      for (final song in songs) {
        batch.insert(_tableName, _songToMap(song), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to insert songs: $e', st));
    }
  }

  Future<Result<void>> update(Song song) async {
    try {
      final db = await _db.database;
      await db.update(_tableName, _songToMap(song), where: 'id = ?', whereArgs: [song.id]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to update song: $e', st));
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      final db = await _db.database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to delete song: $e', st));
    }
  }

  Future<Result<void>> updateLocalPath(String id, String localPath) async {
    try {
      final db = await _db.database;
      await db.update(
        _tableName,
        {'local_path': localPath, 'is_local': 1, 'is_downloaded': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to update local path: $e', st));
    }
  }

  Future<Result<List<Song>>> getDownloaded() async {
    try {
      final db = await _db.database;
      final rows = await db.query(_tableName, where: 'is_downloaded = ?', whereArgs: [1]);
      return Result.success(rows.map(_songFromRow).toList());
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get downloaded songs: $e', st));
    }
  }

  Future<Result<List<Song>>> getLocal() async {
    try {
      final db = await _db.database;
      final rows = await db.query(_tableName, where: 'is_local = ?', whereArgs: [1]);
      return Result.success(rows.map(_songFromRow).toList());
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get local songs: $e', st));
    }
  }

  Future<Result<int>> count() async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return Result.success(result.first['count'] as int);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to count songs: $e', st));
    }
  }

  Future<Result<StreamUrl>> resolveStreamUrl(Song song, {String quality = 'high'}) async {
    // First check if we have a local file
    if (song.isLocal && song.localPath != null) {
      return Result.success(StreamUrl(
        url: 'file://${song.localPath}',
        mimeType: '',
        quality: 'local',
        provider: 'local',
        trackId: song.localPath!,
        isLocal: true,
      ));
    }

    // Check if song is downloaded
    if (song.isDownloaded) {
      final localResult = await _findLocalFile(song);
      if (localResult.isSuccess && localResult.getOrNull() != null) {
        return Result.success(StreamUrl(
          url: 'file://${localResult.getOrNull()!}',
          mimeType: '',
          quality: 'local',
          provider: 'local',
          trackId: localResult.getOrNull()!,
          isLocal: true,
        ));
      }
    }

    // Resolve via MelodiCore (Go backend)
    final request = {
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'duration_ms': song.durationMs,
      'isrc': song.isrc,
      'quality': quality,
      'local_path': song.localPath,
    };

    final result = await _melodiCore.resolveStream(jsonEncode(request));
    if (result.isFailure) {
      return Result.failure(result.getFailure()!);
    }

    try {
      final json = jsonDecode(result.getOrThrow());
      final source = json['source'] as Map<String, dynamic>;
      return Result.success(StreamUrl(
        url: source['url'] as String,
        mimeType: source['mime_type'] as String? ?? '',
        bitrate: source['bitrate'] as int?,
        quality: source['quality'] as String? ?? quality,
        provider: source['provider'] as String? ?? 'unknown',
        trackId: source['track_id'] as String? ?? song.id,
        headers: (source['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
        expiresAt: source['expires_at'] as int?,
        checksum: source['checksum'] as String?,
        size: source['size'] as int?,
        isLocal: json['is_local'] as bool? ?? false,
      ));
    } catch (e, st) {
      return Result.failure(Failure.decoding('Failed to parse stream URL: $e', st));
    }
  }

  Future<Result<String?>> _findLocalFile(Song song) async {
    // Check download manager for completed download
    final downloadsResult = _melodiCore.listDownloads();
    if (downloadsResult.isFailure) return Result.failure(downloadsResult.getFailure()!);

    try {
      final downloads = jsonDecode(downloadsResult.getOrThrow()) as List;
      for (final dl in downloads) {
        final dlMap = dl as Map<String, dynamic>;
        if (dlMap['error'] == null &&
            dlMap['output_path'] != null &&
            (dlMap['isrc'] == song.isrc || dlMap['track_id'] == song.id)) {
          return Result.success(dlMap['output_path'] as String);
        }
      }
    } catch (_) {}
    return const Result.success(null);
  }

  Map<String, dynamic> _songToMap(Song song) => {
    'id': song.id,
    'title': song.title,
    'artist': song.artist,
    'album': song.album,
    'album_artist': song.albumArtist,
    'composer': song.composer,
    'genre': song.genre,
    'year': song.year,
    'track_number': song.trackNumber,
    'disc_number': song.discNumber,
    'duration_ms': song.durationMs,
    'isrc': song.isrc,
    'lyrics': song.lyrics,
    'cover_url': song.coverUrl,
    'local_path': song.localPath,
    'is_local': song.isLocal ? 1 : 0,
    'is_downloaded': song.isDownloaded ? 1 : 0,
    'source': song.source,
    'quality': song.quality,
    'extras': song.extras != null ? jsonEncode(song.extras) : null,
    'created_at': song.createdAt.toIso8601String(),
    'updated_at': song.updatedAt.toIso8601String(),
  };

  Song _songFromRow(Map<String, dynamic> row) => Song(
    id: row['id'] as String,
    title: row['title'] as String,
    artist: row['artist'] as String,
    album: row['album'] as String?,
    albumArtist: row['album_artist'] as String?,
    composer: row['composer'] as String?,
    genre: row['genre'] as String?,
    year: row['year'] as int?,
    trackNumber: row['track_number'] as int?,
    discNumber: row['disc_number'] as int?,
    durationMs: row['duration_ms'] as int?,
    isrc: row['isrc'] as String?,
    lyrics: row['lyrics'] as String?,
    coverUrl: row['cover_url'] as String?,
    localPath: row['local_path'] as String?,
    isLocal: (row['is_local'] as int?) == 1,
    isDownloaded: (row['is_downloaded'] as int?) == 1,
    source: row['source'] as String?,
    quality: row['quality'] as String?,
    extras: row['extras'] != null ? jsonDecode(row['extras'] as String) as Map<String, String> : null,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

import 'dart:convert';
import 'package:sqflite/sqflite.dart';