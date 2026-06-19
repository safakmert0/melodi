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
    if (_database == null || !_database!.isOpen) {
      _database = await _initDatabase();
    }
    return _database!;
  }

  Future<void> resetDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'melodi.db');
      return await openDatabase(
        path,
        version: 18,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE songs ADD COLUMN lyrics TEXT
      ''');
      await db.execute('''
        ALTER TABLE songs ADD COLUMN playbackSpeed REAL DEFAULT 1.0
      ''');
      await db.execute('''
        ALTER TABLE songs ADD COLUMN volumeBoost REAL DEFAULT 1.0
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lyrics_cache (
          songId TEXT PRIMARY KEY,
          plainText TEXT,
          syncedLrc TEXT,
          instrumental INTEGER DEFAULT 0,
          source TEXT,
          fetchedAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mirrored_likes (
          spotifyId TEXT NOT NULL,
          ytMusicVideoId TEXT NOT NULL,
          mirroredAt TEXT NOT NULL,
          PRIMARY KEY (spotifyId, ytMusicVideoId)
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mix_cache (
          mixType TEXT PRIMARY KEY,
          data TEXT NOT NULL,
          generatedAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS error_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          context TEXT,
          message TEXT,
          stackTrace TEXT,
          createdAt TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS high_res_art (
        trackId TEXT PRIMARY KEY,
        url TEXT,
        fetchedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS blocked_tracks (
        trackId TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        blockedAt TEXT
      )
    ''');
  }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wrong_matches (
          spotifyTrackId TEXT NOT NULL,
          badYtVideoId TEXT NOT NULL,
          flaggedAt TEXT NOT NULL,
          resolved INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS playlist_sync_state (
          playlistId TEXT PRIMARY KEY,
          syncEnabled INTEGER DEFAULT 1,
          autoSync INTEGER DEFAULT 0,
          lastSyncedAt TEXT,
          syncDirection TEXT DEFAULT 'bidirectional'
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS track_lyrics (
          trackId TEXT PRIMARY KEY,
          lyrics TEXT,
          syncedLyrics TEXT,
          source TEXT,
          fetchedAt TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS high_res_art (
          trackId TEXT PRIMARY KEY,
          url TEXT,
          fetchedAt TEXT
        )
      ''');
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN imageUrl TEXT');
      } catch (_) {}
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS track_match_cache (
          spotifyId TEXT PRIMARY KEY,
          ytVideoId TEXT NOT NULL,
          confidence REAL NOT NULL,
          matchedAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS downloaded_tracks (
          spotifyTrackId TEXT PRIMARY KEY,
          filePath TEXT NOT NULL,
          downloadedAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS blocked_tracks (
          trackId TEXT PRIMARY KEY,
          title TEXT,
          artist TEXT,
          blockedAt TEXT
        )
      ''');
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS listening_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trackId TEXT,
          title TEXT,
          artist TEXT,
          album TEXT,
          source TEXT,
          durationMs INTEGER,
          playedMs INTEGER,
          isSkip INTEGER DEFAULT 0,
          playedAt TEXT
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_listening_events_trackId ON listening_events(trackId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_listening_events_artist ON listening_events(artist)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_listening_events_playedAt ON listening_events(playedAt)');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS file_organization (
          path TEXT PRIMARY KEY,
          artist TEXT,
          album TEXT,
          filename TEXT,
          organizedTo TEXT,
          organizedAt TEXT
        )
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stream_cache (
          trackId TEXT PRIMARY KEY,
          url TEXT,
          localPath TEXT,
          cachedAt TEXT,
          lastAccessedAt TEXT,
          size INTEGER
        )
      ''');
    }
    if (oldVersion < 18) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS blocked_tracks (
          trackId TEXT PRIMARY KEY,
          title TEXT,
          artist TEXT,
          blockedAt TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_urls (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL,
          sharedAt TEXT NOT NULL,
          processed INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addSharedUrl(String url) async {
    final db = await database;
    await db.insert('shared_urls', {
      'url': url,
      'sharedAt': DateTime.now().toIso8601String(),
      'processed': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSharedUrls() async {
    final db = await database;
    return await db.query('shared_urls',
        where: 'processed = ?', whereArgs: [0], orderBy: 'sharedAt DESC');
  }

  Future<void> markSharedUrlProcessed(int id) async {
    final db = await database;
    await db.update('shared_urls', {'processed': 1}, where: 'id = ?', whereArgs: [id]);
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
        lastPlayed TEXT,
        lyrics TEXT,
        playbackSpeed REAL DEFAULT 1.0,
        volumeBoost REAL DEFAULT 1.0,
        imageUrl TEXT
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
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lyrics_cache (
        songId TEXT PRIMARY KEY,
        plainText TEXT,
        syncedLrc TEXT,
        instrumental INTEGER DEFAULT 0,
        source TEXT,
        fetchedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mirrored_likes (
        spotifyId TEXT NOT NULL,
        ytMusicVideoId TEXT NOT NULL,
        mirroredAt TEXT NOT NULL,
        PRIMARY KEY (spotifyId, ytMusicVideoId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mix_cache (
        mixType TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        generatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS error_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        context TEXT,
        message TEXT,
        stackTrace TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scrobble_history (
        videoId TEXT PRIMARY KEY,
        spotifyTrackId TEXT,
        scrobbledAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS wrong_matches (
        spotifyTrackId TEXT NOT NULL,
        badYtVideoId TEXT NOT NULL,
        flaggedAt TEXT NOT NULL,
        resolved INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_sync_state (
        playlistId TEXT PRIMARY KEY,
        syncEnabled INTEGER DEFAULT 1,
        autoSync INTEGER DEFAULT 0,
        lastSyncedAt TEXT,
        syncDirection TEXT DEFAULT 'bidirectional'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS track_match_cache (
        spotifyId TEXT PRIMARY KEY,
        ytVideoId TEXT NOT NULL,
        confidence REAL NOT NULL,
        matchedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS downloaded_tracks (
        spotifyTrackId TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        downloadedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS track_lyrics (
        trackId TEXT PRIMARY KEY,
        lyrics TEXT,
        syncedLyrics TEXT,
        source TEXT,
        fetchedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS high_res_art (
        trackId TEXT PRIMARY KEY,
        url TEXT,
        fetchedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS listening_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trackId TEXT,
        title TEXT,
        artist TEXT,
        album TEXT,
        source TEXT,
        durationMs INTEGER,
        playedMs INTEGER,
        isSkip INTEGER DEFAULT 0,
        playedAt TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_listening_events_trackId ON listening_events(trackId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_listening_events_artist ON listening_events(artist)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_listening_events_playedAt ON listening_events(playedAt)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_organization (
        path TEXT PRIMARY KEY,
        artist TEXT,
        album TEXT,
        filename TEXT,
        organizedTo TEXT,
        organizedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stream_cache (
        trackId TEXT PRIMARY KEY,
        url TEXT,
        localPath TEXT,
        cachedAt TEXT,
        lastAccessedAt TEXT,
        size INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS blocked_tracks (
        trackId TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        blockedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shared_urls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        sharedAt TEXT NOT NULL,
        processed INTEGER DEFAULT 0
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
    final id = await db.insert('songs', song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (song.albumArt != null) {
      await db.insert('album_art_cache', {
        'songId': song.id,
        'artwork': song.albumArt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return id;
  }

  Future<void> insertSongs(List<SongModel> songs) async {
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert('songs', song.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await cacheAlbumArts(songs);
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
    final song = SongModel.fromMap(maps.first);
    final art = await getCachedAlbumArt(id);
    if (art != null) {
      return song.copyWith(albumArt: art);
    }
    return song;
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

  Future<Map<String, Uint8List>> getAllCachedAlbumArts() async {
    final db = await database;
    final maps = await db.query('album_art_cache');
    final result = <String, Uint8List>{};
    for (final map in maps) {
      final songId = map['songId'] as String?;
      final artwork = map['artwork'] as Uint8List?;
      if (songId != null && songId.isNotEmpty && artwork != null) {
        result[songId] = artwork;
      }
    }
    return result;
  }

  Future<void> cacheAlbumArts(List<SongModel> songs) async {
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      if (song.albumArt != null) {
        batch.insert('album_art_cache', {
          'songId': song.id,
          'artwork': song.albumArt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
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

  Future<Map<String, dynamic>?> getCachedLyrics(String songId) async {
    final db = await database;
    final maps = await db.query('lyrics_cache', where: 'songId = ?', whereArgs: [songId]);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<Map<String, String>?> getCachedMix(String mixType) async {
    final db = await database;
    final maps = await db.query('mix_cache',
        where: 'mixType = ?', whereArgs: [mixType]);
    if (maps.isEmpty) return null;
    return {
      'data': maps.first['data'] as String,
      'generatedAt': maps.first['generatedAt'] as String,
    };
  }

  Future<void> cacheMix(String mixType, String data) async {
    final db = await database;
    await db.insert('mix_cache', {
      'mixType': mixType,
      'data': data,
      'generatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheLyrics(String songId, Map<String, dynamic> data) async {
    final db = await database;
    data['fetchedAt'] = DateTime.now().toIso8601String();
    await db.insert('lyrics_cache', data, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<void> insertErrorLog(String context, String message, String? stackTrace) async {
    final db = await database;
    await db.insert('error_logs', {
      'context': context,
      'message': message,
      'stackTrace': stackTrace ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getErrorLogs(int limit) async {
    final db = await database;
    return db.query('error_logs',
        orderBy: 'id DESC', limit: limit);
  }

  Future<void> clearErrorLogs() async {
    final db = await database;
    await db.delete('error_logs');
  }

  Future<void> insertScrobble(String videoId, String spotifyTrackId) async {
    final db = await database;
    await db.insert('scrobble_history', {
      'videoId': videoId,
      'spotifyTrackId': spotifyTrackId,
      'scrobbledAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getRecentScrobbles(int limit) async {
    final db = await database;
    return db.query('scrobble_history',
        orderBy: 'scrobbledAt DESC', limit: limit);
  }

  Future<int> getScrobbleCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM scrobble_history');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<int> rawInsert(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawInsert(sql, args);
  }

  Future<int> rawDelete(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawDelete(sql, args);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawUpdate(sql, args);
  }

  Future<Map<String, List<SongModel>>> getSongsGroupedByArtist() async {
    final songs = await getAllSongs();
    return groupBy(songs, (SongModel s) => s.artist);
  }

  Future<void> insertWrongMatch(
      String spotifyTrackId, String badYtVideoId) async {
    final db = await database;
    await db.insert('wrong_matches', {
      'spotifyTrackId': spotifyTrackId,
      'badYtVideoId': badYtVideoId,
      'flaggedAt': DateTime.now().toIso8601String(),
      'resolved': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getWrongMatches(
      {bool resolved = false}) async {
    final db = await database;
    return db.query('wrong_matches',
        where: 'resolved = ?', whereArgs: [resolved ? 1 : 0]);
  }

  Future<void> resolveWrongMatch(String spotifyTrackId) async {
    final db = await database;
    await db.update('wrong_matches', {'resolved': 1},
        where: 'spotifyTrackId = ?', whereArgs: [spotifyTrackId]);
  }

  Future<Map<String, dynamic>?> getPlaylistSyncState(String playlistId) async {
    final db = await database;
    final maps = await db.query('playlist_sync_state',
        where: 'playlistId = ?', whereArgs: [playlistId]);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> setPlaylistSyncEnabled(String playlistId, bool enabled) async {
    final db = await database;
    await db.insert('playlist_sync_state', {
      'playlistId': playlistId,
      'syncEnabled': enabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setAutoSync(String playlistId, bool autoSync) async {
    final db = await database;
    await db.insert('playlist_sync_state', {
      'playlistId': playlistId,
      'autoSync': autoSync ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setSyncDirection(String playlistId, String direction) async {
    final db = await database;
    await db.insert('playlist_sync_state', {
      'playlistId': playlistId,
      'syncDirection': direction,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Map<String, dynamic>>> getAllSyncStates() async {
    final db = await database;
    final maps = await db.query('playlist_sync_state');
    final result = <String, Map<String, dynamic>>{};
    for (final map in maps) {
      result[map['playlistId'] as String] = map;
    }
    return result;
  }

  Future<Map<String, dynamic>?> getLyrics(String trackId) async {
    final db = await database;
    final maps = await db.query('track_lyrics', where: 'trackId = ?', whereArgs: [trackId]);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> saveLyrics(String trackId, Map<String, dynamic> data) async {
    final db = await database;
    data['trackId'] = trackId;
    data['fetchedAt'] = DateTime.now().toIso8601String();
    await db.insert('track_lyrics', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getHighResArtUrl(String trackId) async {
    final db = await database;
    final maps = await db.query('high_res_art', where: 'trackId = ?', whereArgs: [trackId]);
    if (maps.isEmpty) return null;
    return maps.first['url'] as String?;
  }

  Future<void> saveHighResArtUrl(String trackId, String url) async {
    final db = await database;
    await db.insert('high_res_art', {
      'trackId': trackId,
      'url': url,
      'fetchedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTracksMissingArt() async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.id, s.title, s.artist, s.album FROM songs s
      WHERE s.imageUrl IS NULL OR s.imageUrl = ''
    ''');
  }

  Future<List<Map<String, dynamic>>> getTracksMissingMetadata() async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.id, s.title, s.artist, s.album, s.durationMs FROM songs s
      WHERE s.album = 'Unknown Album' OR s.artist = 'Unknown Artist' OR s.durationMs = 0
    ''');
  }

  Future<void> updateTrackImageUrl(String trackId, String imageUrl) async {
    final db = await database;
    await db.update('songs', {'imageUrl': imageUrl}, where: 'id = ?', whereArgs: [trackId]);
  }

  Future<void> updateTrackMetadata(String trackId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('songs', data, where: 'id = ?', whereArgs: [trackId]);
  }

  Future<Map<String, dynamic>?> getCachedMatch(String spotifyId) async {
    final db = await database;
    final maps = await db.query(
      'track_match_cache',
      where: 'spotifyId = ?',
      whereArgs: [spotifyId],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> cacheMatch(
      String spotifyId, String ytVideoId, double confidence) async {
    final db = await database;
    await db.insert(
      'track_match_cache',
      {
        'spotifyId': spotifyId,
        'ytVideoId': ytVideoId,
        'confidence': confidence,
        'matchedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, double>> getAllCachedConfidences() async {
    final db = await database;
    final maps = await db.query('track_match_cache');
    final result = <String, double>{};
    for (final map in maps) {
      final spotifyId = map['spotifyId'] as String?;
      final confidence = map['confidence'] as double?;
      if (spotifyId != null && confidence != null) {
        result[spotifyId] = confidence;
      }
    }
    return result;
  }

  Future<void> insertFailedMatch(String spotifyTrackId, String filePath) async {
    final db = await database;
    await db.insert(
      'downloaded_tracks',
      {
        'spotifyTrackId': spotifyTrackId,
        'filePath': filePath,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedTracks() async {
    final db = await database;
    return db.query('downloaded_tracks', orderBy: 'downloadedAt DESC');
  }

  Future<List<Map<String, dynamic>>> getTracksNeedingRematch() async {
    final db = await database;
    return db.rawQuery('''
      SELECT tmc.* FROM track_match_cache tmc
      WHERE tmc.confidence < 0.7
      ORDER BY tmc.matchedAt ASC
    ''');
  }

  Future<int> insertListeningEvent(Map<String, dynamic> event) async {
    final db = await database;
    return await db.insert('listening_events', event);
  }

  Future<List<Map<String, dynamic>>> getRecentPlays(int limit) async {
    final db = await database;
    return db.query('listening_events',
        where: 'isSkip = 0',
        orderBy: 'playedAt DESC',
        limit: limit);
  }

  Future<List<Map<String, dynamic>>> getTopArtists(int limit,
      {String period = 'all'}) async {
    final db = await database;
    final where = _periodWhereClause(period);
    final whereStr = where.isNotEmpty ? 'WHERE isSkip = 0 AND $where' : 'WHERE isSkip = 0';
    return db.rawQuery('''
      SELECT artist, COUNT(*) as playCount
      FROM listening_events
      $whereStr
      GROUP BY artist
      ORDER BY playCount DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getTopTracks(int limit,
      {String period = 'all'}) async {
    final db = await database;
    final where = _periodWhereClause(period);
    final whereStr = where.isNotEmpty ? 'WHERE isSkip = 0 AND $where' : 'WHERE isSkip = 0';
    return db.rawQuery('''
      SELECT trackId, title, artist, COUNT(*) as playCount
      FROM listening_events
      $whereStr
      GROUP BY trackId
      ORDER BY playCount DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<int> getPlayCountByTrack(String trackId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM listening_events WHERE trackId = ? AND isSkip = 0',
        [trackId]);
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getPlayCountByArtist(String artistName) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM listening_events WHERE artist = ? AND isSkip = 0',
        [artistName]);
    return (result.first['count'] as int?) ?? 0;
  }

  Future<Map<String, dynamic>> getListeningStats() async {
    final db = await database;
    final totalPlays = await db.rawQuery(
        'SELECT COUNT(*) as count FROM listening_events WHERE isSkip = 0');
    final totalTime = await db.rawQuery(
        'SELECT COALESCE(SUM(durationMs), 0) as total FROM listening_events WHERE isSkip = 0');
    final uniqueArtists = await db.rawQuery(
        'SELECT COUNT(DISTINCT artist) as count FROM listening_events WHERE isSkip = 0');
    final uniqueTracks = await db.rawQuery(
        'SELECT COUNT(DISTINCT trackId) as count FROM listening_events WHERE isSkip = 0');
    return {
      'totalPlays': (totalPlays.first['count'] as int?) ?? 0,
      'totalListeningTimeMs': (totalTime.first['total'] as int?) ?? 0,
      'uniqueArtists': (uniqueArtists.first['count'] as int?) ?? 0,
      'uniqueTracks': (uniqueTracks.first['count'] as int?) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getListeningHistoryByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return db.query('listening_events',
        where: 'playedAt >= ? AND playedAt < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
        orderBy: 'playedAt ASC');
  }

  Future<void> insertFileRecord(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert('file_organization', {
      'path': record['path'],
      'artist': record['artist'],
      'album': record['album'],
      'filename': record['filename'],
      'organizedTo': record['organizedTo'],
      'organizedAt': record['organizedAt'] ?? DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getFileRecords() async {
    final db = await database;
    return db.query('file_organization');
  }

  Future<List<String>> getArtists() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT artist FROM file_organization ORDER BY artist');
    return result.map((r) => r['artist'] as String).toList();
  }

  Future<List<String>> getAlbumsForArtist(String artist) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT album FROM file_organization WHERE artist = ? ORDER BY album',
      [artist],
    );
    return result.map((r) => r['album'] as String).toList();
  }

  Future<int> getOrganizedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM file_organization');
    return (result.first['count'] as int?) ?? 0;
  }

  String _periodWhereClause(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'day':
        final start = DateTime(now.year, now.month, now.day);
        return "playedAt >= '${start.toIso8601String()}'";
      case 'week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(start.year, start.month, start.day);
        return "playedAt >= '${weekStart.toIso8601String()}'";
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        return "playedAt >= '${start.toIso8601String()}'";
      case 'year':
        final start = DateTime(now.year, 1, 1);
        return "playedAt >= '${start.toIso8601String()}'";
      default:
        return '';
    }
  }

  Future<void> insertCacheEntry({
    required String trackId,
    required String url,
    required String localPath,
    required int size,
    required String cachedAt,
    required String lastAccessedAt,
  }) async {
    final db = await database;
    await db.insert('stream_cache', {
      'trackId': trackId,
      'url': url,
      'localPath': localPath,
      'cachedAt': cachedAt,
      'lastAccessedAt': lastAccessedAt,
      'size': size,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCacheEntry(String trackId) async {
    final db = await database;
    final maps = await db.query('stream_cache',
        where: 'trackId = ?', whereArgs: [trackId]);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> updateLastAccessed(String trackId) async {
    final db = await database;
    await db.update('stream_cache', {
      'lastAccessedAt': DateTime.now().toIso8601String(),
    }, where: 'trackId = ?', whereArgs: [trackId]);
  }

  Future<void> removeCacheEntry(String trackId) async {
    final db = await database;
    await db.delete('stream_cache',
        where: 'trackId = ?', whereArgs: [trackId]);
  }

  Future<List<Map<String, dynamic>>> getAllCacheEntries({
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query('stream_cache', orderBy: orderBy, limit: limit);
  }

  Future<int> getTotalCacheSize() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(size), 0) as total FROM stream_cache');
    return (result.first['total'] as int?) ?? 0;
  }
}
