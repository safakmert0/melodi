import '../services/database_service.dart';

class BlockedTrack {
  final String trackId;
  final String title;
  final String artist;
  final String blockedAt;

  const BlockedTrack({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.blockedAt,
  });

  Map<String, dynamic> toMap() => {
    'trackId': trackId,
    'title': title,
    'artist': artist,
    'blockedAt': blockedAt,
  };

  factory BlockedTrack.fromMap(Map<String, dynamic> map) => BlockedTrack(
    trackId: map['trackId'] as String,
    title: map['title'] as String? ?? '',
    artist: map['artist'] as String? ?? '',
    blockedAt: map['blockedAt'] as String? ?? '',
  );
}

class BlocklistService {
  static BlocklistService? _instance;

  BlocklistService._();

  static BlocklistService get instance {
    _instance ??= BlocklistService._();
    return _instance!;
  }

  Future<void> blockTrack(String trackId, String title, String artist) async {
    final db = DatabaseService.instance;
    await db.rawInsert('''
      INSERT OR REPLACE INTO blocked_tracks (trackId, title, artist, blockedAt)
      VALUES (?, ?, ?, ?)
    ''', [trackId, title, artist, DateTime.now().toIso8601String()]);
  }

  Future<void> unblockTrack(String trackId) async {
    final db = DatabaseService.instance;
    await db.rawQuery(
      'DELETE FROM blocked_tracks WHERE trackId = ?',
      [trackId],
    );
  }

  Future<void> unblockByTitleArtist(String title, String artist) async {
    final db = DatabaseService.instance;
    await db.rawQuery(
      'DELETE FROM blocked_tracks WHERE title = ? AND artist = ?',
      [title, artist],
    );
  }

  Future<bool> isBlocked(String trackId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
      'SELECT 1 FROM blocked_tracks WHERE trackId = ? LIMIT 1',
      [trackId],
    );
    return result.isNotEmpty;
  }

  Future<bool> isBlockedByTitleArtist(String title, String artist) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
      'SELECT 1 FROM blocked_tracks WHERE LOWER(title) = LOWER(?) AND LOWER(artist) = LOWER(?) LIMIT 1',
      [title, artist],
    );
    return result.isNotEmpty;
  }

  Future<List<BlockedTrack>> getBlockedTracks() async {
    final db = DatabaseService.instance;
    final maps = await db.rawQuery(
      'SELECT * FROM blocked_tracks ORDER BY blockedAt DESC',
    );
    return maps.map((m) => BlockedTrack.fromMap(m)).toList();
  }

  Future<int> getBlockedCount() async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM blocked_tracks');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<BlockedTrack>> searchBlockedTracks(String query) async {
    final db = DatabaseService.instance;
    final term = '%$query%';
    final maps = await db.rawQuery('''
      SELECT * FROM blocked_tracks
      WHERE title LIKE ? OR artist LIKE ?
      ORDER BY blockedAt DESC
    ''', [term, term]);
    return maps.map((m) => BlockedTrack.fromMap(m)).toList();
  }
}
