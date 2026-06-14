import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

class DatabaseService {
  static Database? _database;
  static DatabaseService? _instance;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'melodi.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        albumArtist TEXT,
        durationMs INTEGER NOT NULL,
        filePath TEXT NOT NULL UNIQUE,
        genre TEXT,
        trackNumber INTEGER,
        discNumber INTEGER,
        year INTEGER,
        bitrate INTEGER,
        sampleRate INTEGER,
        mimeType TEXT,
        fileSize INTEGER NOT NULL,
        dateAdded TEXT NOT NULL,
        isFavorite INTEGER DEFAULT 0,
        playCount INTEGER DEFAULT 0,
        lastPlayed TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        songIds TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSmartPlaylist INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE album_art_cache (
        songId TEXT PRIMARY KEY,
        artwork BLOB,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_songs_artist ON songs(artist)
    ''');
    await db.execute('''
      CREATE INDEX idx_songs_album ON songs(album)
    ''');
    await db.execute('''
      CREATE INDEX idx_songs_favorite ON songs(isFavorite)
    ''');
  }

  Future<int> insertSong(SongModel song) async {
    final db = await database;
    return await db.insert('songs', song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSongs(List<SongModel> songs) async {
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert('songs', song.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<SongModel>> getAllSongs() async {
    final db = await database;
    final maps = await db.query('songs', orderBy: 'title ASC');
    return maps.map((m) => SongModel.fromMap(m)).toList();
  }

  Future<List<SongModel>> getFavoriteSongs() async {
    final db = await database;
    final maps = await db.query('songs',
        where: 'isFavorite = ?', whereArgs: [1], orderBy: 'title ASC');
    return maps.map((m) => SongModel.fromMap(m)).toList();
  }

  Future<List<SongModel>> getRecentSongs({int limit = 20}) async {
    final db = await database;
    final maps = await db.query('songs',
        orderBy: 'lastPlayed DESC',
        where: 'lastPlayed IS NOT NULL',
        limit: limit);
    return maps.map((m) => SongModel.fromMap(m)).toList();
  }

  Future<List<SongModel>> getMostPlayedSongs({int limit = 20}) async {
    final db = await database;
    final maps = await db.query('songs',
        orderBy: 'playCount DESC', limit: limit);
    return maps.map((m) => SongModel.fromMap(m)).toList();
  }

  Future<SongModel?> getSongById(String id) async {
    final db = await database;
    final maps = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return SongModel.fromMap(maps.first);
  }

  Future<SongModel?> getSongByPath(String path) async {
    final db = await database;
    final maps =
        await db.query('songs', where: 'filePath = ?', whereArgs: [path]);
    if (maps.isEmpty) return null;
    return SongModel.fromMap(maps.first);
  }

  Future<void> updateFavoriteStatus(String songId, bool isFavorite) async {
    final db = await database;
    await db.update('songs', {'isFavorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<void> updatePlayCount(String songId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE songs SET playCount = playCount + 1, lastPlayed = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), songId]);
  }

  Future<void> deleteSong(String id) async {
    final db = await database;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
    await db.delete('album_art_cache', where: 'songId = ?', whereArgs: [id]);
  }

  Future<void> deleteSongsNotInPaths(Set<String> validPaths) async {
    final db = await database;
    final placeholders = validPaths.map((_) => '?').join(',');
    await db.rawDelete(
        'DELETE FROM songs WHERE filePath NOT IN ($placeholders)',
        validPaths.toList());
  }

  Future<void> cacheAlbumArt(String songId, Uint8List artwork) async {
    final db = await database;
    await db.insert('album_art_cache', {
      'songId': songId,
      'artwork': artwork,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Uint8List?> getCachedAlbumArt(String songId) async {
    final db = await database;
    final maps = await db.query('album_art_cache',
        where: 'songId = ?', whereArgs: [songId]);
    if (maps.isEmpty) return null;
    return maps.first['artwork'] as Uint8List?;
  }

  Future<int> insertPlaylist(PlaylistModel playlist) async {
    final db = await database;
    return await db.insert('playlists', playlist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PlaylistModel>> getAllPlaylists() async {
    final db = await database;
    final maps = await db.query('playlists', orderBy: 'updatedAt DESC');
    return maps.map((m) => PlaylistModel.fromMap(m)).toList();
  }

  Future<void> updatePlaylistSongs(String playlistId, List<String> songIds) async {
    final db = await database;
    await db.update('playlists', {
      'songIds': songIds.join(','),
      'updatedAt': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [playlistId]);
  }

  Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('songs');
    await db.delete('playlists');
    await db.delete('album_art_cache');
  }

  Future<List<SongModel>> searchSongs(String query) async {
    final db = await database;
    final searchTerm = '%$query%';
    final maps = await db.query('songs',
        where:
            'title LIKE ? OR artist LIKE ? OR album LIKE ?',
        whereArgs: [searchTerm, searchTerm, searchTerm],
        orderBy: 'title ASC');
    return maps.map((m) => SongModel.fromMap(m)).toList();
  }

  Future<Map<String, List<SongModel>>> getSongsGroupedByAlbum() async {
    final songs = await getAllSongs();
    return groupBy(songs, (SongModel s) => s.album);
  }

  Future<Map<String, List<SongModel>>> getSongsGroupedByArtist() async {
    final songs = await getAllSongs();
    return groupBy(songs, (SongModel s) => s.artist);
  }
}
