import 'dart:io';
import 'package:path/path.dart' as p;
import 'database_service.dart';

class AudiobookChapter {
  final String id;
  final String title;
  final String audioPath;
  final Duration duration;
  final int position;
  bool completed;

  AudiobookChapter({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.duration,
    required this.position,
    this.completed = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'audioPath': audioPath,
    'durationMs': duration.inMilliseconds,
    'position': position,
    'completed': completed ? 1 : 0,
  };

  factory AudiobookChapter.fromMap(Map<String, dynamic> map) => AudiobookChapter(
    id: map['id'] as String,
    title: map['title'] as String? ?? '',
    audioPath: map['audioPath'] as String? ?? '',
    duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
    position: map['position'] as int? ?? 0,
    completed: (map['completed'] as int? ?? 0) == 1,
  );
}

class Audiobook {
  final String id;
  final String title;
  final String author;
  final List<AudiobookChapter> chapters;
  final String folderPath;
  final DateTime createdAt;

  const Audiobook({
    required this.id,
    required this.title,
    required this.author,
    required this.chapters,
    required this.folderPath,
    required this.createdAt,
  });

  Duration get totalDuration => chapters.fold(Duration.zero, (sum, ch) => sum + ch.duration);

  double get progress {
    if (chapters.isEmpty) return 0;
    final completedCount = chapters.where((ch) => ch.completed).length;
    return completedCount / chapters.length;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'author': author,
    'chapters': chapters.map((c) => c.toMap()).toList(),
    'folderPath': folderPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Audiobook.fromMap(Map<String, dynamic> map) {
    final chaptersList = (map['chapters'] as List?)
        ?.map((c) => AudiobookChapter.fromMap(c as Map<String, dynamic>))
        .toList();
    return Audiobook(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      chapters: chaptersList ?? [],
      folderPath: map['folderPath'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AudiobookBookmark {
  final String id;
  final String audiobookId;
  final String chapterId;
  final Duration position;
  final String? note;
  final DateTime createdAt;

  const AudiobookBookmark({
    required this.id,
    required this.audiobookId,
    required this.chapterId,
    required this.position,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'audiobookId': audiobookId,
    'chapterId': chapterId,
    'positionMs': position.inMilliseconds,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AudiobookBookmark.fromMap(Map<String, dynamic> map) => AudiobookBookmark(
    id: map['id'] as String,
    audiobookId: map['audiobookId'] as String? ?? '',
    chapterId: map['chapterId'] as String? ?? '',
    position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
    note: map['note'] as String?,
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class AudiobookService {
  static AudiobookService? _instance;

  AudiobookService._();

  static AudiobookService get instance {
    _instance ??= AudiobookService._();
    return _instance!;
  }

  Future<void> _ensureTables() async {
    final db = DatabaseService.instance;
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS audiobooks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        folderPath TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS audiobook_chapters (
        id TEXT PRIMARY KEY,
        audiobookId TEXT NOT NULL,
        title TEXT NOT NULL,
        audioPath TEXT NOT NULL,
        durationMs INTEGER DEFAULT 0,
        position INTEGER DEFAULT 0,
        completed INTEGER DEFAULT 0,
        FOREIGN KEY (audiobookId) REFERENCES audiobooks(id) ON DELETE CASCADE
      )
    ''');
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS audiobook_progress (
        audiobookId TEXT PRIMARY KEY,
        chapterId TEXT NOT NULL,
        positionMs INTEGER DEFAULT 0,
        lastPlayedAt TEXT NOT NULL
      )
    ''');
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS audiobook_bookmarks (
        id TEXT PRIMARY KEY,
        audiobookId TEXT NOT NULL,
        chapterId TEXT NOT NULL,
        positionMs INTEGER DEFAULT 0,
        note TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (audiobookId) REFERENCES audiobooks(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<Audiobook?> loadAudiobook(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return null;

    final audioExtensions = {'.mp3', '.m4a', '.aac', '.ogg', '.flac', '.wav', '.opus', '.wma'};
    final files = <FileSystemEntity>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (audioExtensions.contains(ext)) {
          files.add(entity);
        }
      }
    }

    if (files.isEmpty) return null;

    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final chapters = <AudiobookChapter>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i] as File;
      final title = p.basenameWithoutExtension(file.path);
      final id = '${path.hashCode}_${i}_${title.hashCode}';
      chapters.add(AudiobookChapter(
        id: id,
        title: title,
        audioPath: file.path,
        duration: Duration.zero,
        position: i,
      ));
    }

    final folderName = p.basename(path);
    final authorMatch = RegExp(r'^(.+?)\s*[-–]\s*.+').firstMatch(folderName);
    final author = authorMatch?.group(1)?.trim() ?? 'Unknown Author';

    final id = path.hashCode.toRadixString(16);
    return Audiobook(
      id: id,
      title: folderName,
      author: author,
      chapters: chapters,
      folderPath: path,
      createdAt: DateTime.now(),
    );
  }

  Future<void> saveAudiobook(Audiobook book) async {
    await _ensureTables();
    final db = DatabaseService.instance;
    await db.rawInsert('''
      INSERT OR REPLACE INTO audiobooks (id, title, author, folderPath, createdAt)
      VALUES (?, ?, ?, ?, ?)
    ''', [book.id, book.title, book.author, book.folderPath, book.createdAt.toIso8601String()]);

    for (final ch in book.chapters) {
      await db.rawInsert('''
        INSERT OR REPLACE INTO audiobook_chapters (id, audiobookId, title, audioPath, durationMs, position, completed)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [ch.id, book.id, ch.title, ch.audioPath, ch.duration.inMilliseconds, ch.position, ch.completed ? 1 : 0]);
    }
  }

  Future<List<Audiobook>> getAllAudiobooks() async {
    await _ensureTables();
    final db = DatabaseService.instance;
    final bookMaps = await db.rawQuery('SELECT * FROM audiobooks ORDER BY createdAt DESC');

    final books = <Audiobook>[];
    for (final bookMap in bookMaps) {
      final chapterMaps = await db.rawQuery(
        'SELECT * FROM audiobook_chapters WHERE audiobookId = ? ORDER BY position',
        [bookMap['id']],
      );
      final chapters = chapterMaps.map((m) => AudiobookChapter.fromMap(m)).toList();
      books.add(Audiobook.fromMap({...bookMap, 'chapters': chapters}));
    }
    return books;
  }

  Future<Audiobook?> getAudiobook(String id) async {
    await _ensureTables();
    final db = DatabaseService.instance;
    final bookMaps = await db.rawQuery('SELECT * FROM audiobooks WHERE id = ?', [id]);
    if (bookMaps.isEmpty) return null;

    final bookMap = bookMaps.first;
    final chapterMaps = await db.rawQuery(
      'SELECT * FROM audiobook_chapters WHERE audiobookId = ? ORDER BY position',
      [id],
    );
    final chapters = chapterMaps.map((m) => AudiobookChapter.fromMap(m)).toList();
    return Audiobook.fromMap({...bookMap, 'chapters': chapters});
  }

  Future<void> deleteAudiobook(String id) async {
    final db = DatabaseService.instance;
    await db.rawQuery('DELETE FROM audiobooks WHERE id = ?', [id]);
    await db.rawQuery('DELETE FROM audiobook_chapters WHERE audiobookId = ?', [id]);
    await db.rawQuery('DELETE FROM audiobook_progress WHERE audiobookId = ?', [id]);
    await db.rawQuery('DELETE FROM audiobook_bookmarks WHERE audiobookId = ?', [id]);
  }

  Future<void> saveProgress(String audiobookId, String chapterId, Duration position) async {
    await _ensureTables();
    final db = DatabaseService.instance;
    await db.rawInsert('''
      INSERT OR REPLACE INTO audiobook_progress (audiobookId, chapterId, positionMs, lastPlayedAt)
      VALUES (?, ?, ?, ?)
    ''', [audiobookId, chapterId, position.inMilliseconds, DateTime.now().toIso8601String()]);
  }

  Future<(String chapterId, Duration position)?> getProgress(String audiobookId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery('SELECT * FROM audiobook_progress WHERE audiobookId = ?', [audiobookId]);
    if (result.isEmpty) return null;
    final row = result.first;
    return (
      row['chapterId'] as String,
      Duration(milliseconds: row['positionMs'] as int? ?? 0),
    );
  }

  Future<void> markChapterCompleted(String chapterId) async {
    final db = DatabaseService.instance;
    await db.rawUpdate(
      'UPDATE audiobook_chapters SET completed = 1 WHERE id = ?',
      [chapterId],
    );
  }

  Future<AudiobookBookmark> addBookmark(String audiobookId, String chapterId, Duration position, {String? note}) async {
    await _ensureTables();
    final db = DatabaseService.instance;
    final id = '${audiobookId}_${DateTime.now().millisecondsSinceEpoch}';
    final bookmark = AudiobookBookmark(
      id: id,
      audiobookId: audiobookId,
      chapterId: chapterId,
      position: position,
      note: note,
      createdAt: DateTime.now(),
    );
    final map = bookmark.toMap();
    await db.rawInsert('''
      INSERT INTO audiobook_bookmarks (id, audiobookId, chapterId, positionMs, note, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [map['id'], map['audiobookId'], map['chapterId'], map['positionMs'], map['note'], map['createdAt']]);
    return bookmark;
  }

  Future<List<AudiobookBookmark>> getBookmarks(String audiobookId) async {
    final db = DatabaseService.instance;
    final maps = await db.rawQuery(
      'SELECT * FROM audiobook_bookmarks WHERE audiobookId = ? ORDER BY createdAt DESC',
      [audiobookId],
    );
    return maps.map((m) => AudiobookBookmark.fromMap(m)).toList();
  }

  Future<void> removeBookmark(String bookmarkId) async {
    final db = DatabaseService.instance;
    await db.rawQuery('DELETE FROM audiobook_bookmarks WHERE id = ?', [bookmarkId]);
  }
}
