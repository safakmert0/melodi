import 'package:melodi/core/errors.dart';
import 'package:melodi/data/datasources/local/db_service.dart';
import 'package:melodi/data/models/song.dart';

class AlbumRepository {
  final DbService _db;

  AlbumRepository({required DbService db}) : _db = _db;

  static const String _tableName = 'albums';

  Future<Result<List<Album>>> getAll({
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
        sql += ' WHERE title LIKE ? OR artist LIKE ?';
        final searchTerm = '%$query%';
        args.addAll([searchTerm, searchTerm]);
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
      return Result.success(rows.map(_albumFromRow).toList());
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get albums: $e', st));
    }
  }

  Future<Result<Album?>> getById(String id) async {
    try {
      final db = await _db.database;
      final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return const Result.success(null);
      return Result.success(_albumFromRow(rows.first));
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get album: $e', st));
    }
  }

  Future<Result<Album>> insert(Album album) async {
    try {
      final db = await _db.database;
      await db.insert(_tableName, _albumToMap(album), conflictAlgorithm: ConflictAlgorithm.replace);
      return Result.success(album);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to insert album: $e', st));
    }
  }

  Future<Result<void>> insertAll(List<Album> albums) async {
    try {
      final db = await _db.database;
      final batch = db.batch();
      for (final album in albums) {
        batch.insert(_tableName, _albumToMap(album), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to insert albums: $e', st));
    }
  }

  Future<Result<void>> update(Album album) async {
    try {
      final db = await _db.database;
      await db.update(_tableName, _albumToMap(album), where: 'id = ?', whereArgs: [album.id]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to update album: $e', st));
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      final db = await _db.database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to delete album: $e', st));
    }
  }

  Future<Result<List<Album>>> getByArtist(String artistId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(_tableName, where: 'artist_id = ?', whereArgs: [artistId]);
      return Result.success(rows.map(_albumFromRow).toList());
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to get albums by artist: $e', st));
    }
  }

  Future<Result<int>> count() async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return Result.success(result.first['count'] as int);
    } catch (e, st) {
      return Result.failure(Failure.storage('Failed to count albums: $e', st));
    }
  }

  Map<String, dynamic> _albumToMap(Album album) => {
    'id': album.id,
    'title': album.title,
    'artist': album.artist,
    'artist_id': album.artistId,
    'cover_url': album.coverUrl,
    'year': album.year,
    'genre': album.genre,
    'track_count': album.trackCount,
    'duration_ms': album.durationMs,
    'is_local': album.isLocal ? 1 : 0,
    'is_downloaded': album.isDownloaded ? 1 : 0,
    'created_at': album.createdAt.toIso8601String(),
    'updated_at': album.updatedAt.toIso8601String(),
  };

  Album _albumFromRow(Map<String, dynamic> row) => Album(
    id: row['id'] as String,
    title: row['title'] as String,
    artist: row['artist'] as String,
    artistId: row['artist_id'] as String?,
    coverUrl: row['cover_url'] as String?,
    year: row['year'] as int?,
    genre: row['genre'] as String?,
    trackCount: row['track_count'] as int?,
    durationMs: row['duration_ms'] as int?,
    isLocal: (row['is_local'] as int?) == 1,
    isDownloaded: (row['is_downloaded'] as int?) == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

import 'package:sqflite/sqflite.dart';