import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/song_model.dart';
import 'download_manager.dart';
import 'storage_manager.dart';

class PodcastEpisode {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final Duration duration;
  final DateTime publishDate;
  final String? imageUrl;

  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.duration,
    required this.publishDate,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'audioUrl': audioUrl,
        'durationMs': duration.inMilliseconds,
        'publishDate': publishDate.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory PodcastEpisode.fromMap(Map<String, dynamic> map) => PodcastEpisode(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        audioUrl: map['audioUrl'] as String? ?? '',
        duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
        publishDate: DateTime.tryParse(map['publishDate'] as String? ?? '') ??
            DateTime.now(),
        imageUrl: map['imageUrl'] as String?,
      );
}

class PodcastFeed {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final List<PodcastEpisode> episodes;
  final String rssUrl;
  final DateTime fetchedAt;

  const PodcastFeed({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.episodes,
    required this.rssUrl,
    required this.fetchedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'episodes': jsonEncode(episodes.map((e) => e.toMap()).toList()),
        'rssUrl': rssUrl,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory PodcastFeed.fromMap(Map<String, dynamic> map) {
    final episodesJson = map['episodes'] as String? ?? '[]';
    final episodesList = (jsonDecode(episodesJson) as List)
        .map((e) => PodcastEpisode.fromMap(e as Map<String, dynamic>))
        .toList();
    return PodcastFeed(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      episodes: episodesList,
      rssUrl: map['rssUrl'] as String? ?? '',
      fetchedAt: DateTime.tryParse(map['fetchedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PodcastService {
  static PodcastService? _instance;
  final http.Client _client;

  PodcastService._({http.Client? client}) : _client = client ?? http.Client();

  static PodcastService get instance {
    _instance ??= PodcastService._();
    return _instance!;
  }

  Future<void> _ensureTable() async {
    final db = DatabaseService.instance;
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS podcast_subscriptions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        imageUrl TEXT,
        rssUrl TEXT NOT NULL,
        episodes TEXT DEFAULT '[]',
        fetchedAt TEXT NOT NULL,
        subscribedAt TEXT NOT NULL
      )
    ''');
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS podcast_progress (
        episodeId TEXT PRIMARY KEY,
        podcastId TEXT NOT NULL,
        positionMs INTEGER DEFAULT 0,
        completed INTEGER DEFAULT 0,
        lastPlayedAt TEXT NOT NULL
      )
    ''');
    await db.rawInsert('''
      CREATE TABLE IF NOT EXISTS podcast_downloads (
        episodeId TEXT PRIMARY KEY,
        podcastId TEXT NOT NULL,
        localPath TEXT NOT NULL,
        downloadedAt TEXT NOT NULL
      )
    ''');
  }

  /// Whether a pasted/opened URL is likely a podcast feed or episode.
  static bool isPodcastUrl(String url) {
    final u = url.trim().toLowerCase();
    if (!u.startsWith('http://') && !u.startsWith('https://')) return false;
    if (RegExp(r'\.(mp3|m4a|aac|ogg|opus|wav|flac)(\?|$)').hasMatch(u)) {
      return true;
    }
    if (u.endsWith('.xml') ||
        u.endsWith('.rss') ||
        u.contains('feed') ||
        u.contains('rss') ||
        u.contains('podcast')) {
      return true;
    }
    const hosts = [
      'feeds.',
      'feed.',
      'podcasts.',
      'pinecast',
      'buzzsprout',
      'anchor.fm',
      'libsyn',
      'simplecast',
      'fireside.fm',
      'transistor.fm',
      'redcircle',
      'megaphone.fm',
      'acast',
      'soundcloud.com',
      'feeds.',
      'podbay',
      'stitcher',
    ];
    return hosts.any((h) => u.contains(h));
  }

  /// Resolve a feed URL or a single episode (audio file) URL into a feed.
  Future<PodcastFeed> resolveUrl(String url) async {
    final trimmed = url.trim();
    if (RegExp(r'\.(mp3|m4a|aac|ogg|opus|wav|flac)(\?|$)',
            caseSensitive: false)
        .hasMatch(trimmed)) {
      final fileName =
          Uri.parse(trimmed).pathSegments.lastOrNull?.split('?').first ??
              'Episode';
      final id = _hashUrl(trimmed);
      final ep = PodcastEpisode(
        id: id,
        title: _prettyName(fileName),
        description: '',
        audioUrl: trimmed,
        duration: Duration.zero,
        publishDate: DateTime.now(),
      );
      return PodcastFeed(
        id: _hashUrl('single:$trimmed'),
        title: _prettyName(fileName),
        description: 'Single episode',
        episodes: [ep],
        rssUrl: trimmed,
        fetchedAt: DateTime.now(),
      );
    }

    final response = await _client.get(Uri.parse(trimmed));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch podcast: ${response.statusCode}');
    }
    final xml = response.body;
    if (xml.contains('<rss') || xml.contains('<channel')) {
      return _parseRss(xml, trimmed);
    }
    throw FormatException('Not a podcast feed: $trimmed');
  }

  Future<PodcastFeed> fetchFeed(String rssUrl) async {
    final response = await _client.get(Uri.parse(rssUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch podcast feed: ${response.statusCode}');
    }
    return _parseRss(response.body, rssUrl);
  }

  PodcastFeed _parseRss(String xml, String rssUrl) {
    final channelMatch =
        RegExp(r'<channel>(.*?)</channel>', dotAll: true).firstMatch(xml);
    if (channelMatch == null)
      throw FormatException('Invalid RSS: no channel element');

    final channel = channelMatch.group(1)!;
    final title = _extractTag(channel, 'title');
    final description = _extractTag(channel, 'description') ??
        _extractTag(channel, 'itunes:summary');
    final imageUrl = _extractImageUrl(channel);

    final items =
        RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(channel);
    final episodes =
        items.map((m) => _parseEpisode(m.group(1)!, title ?? '')).toList();

    final id = _hashUrl(rssUrl);

    return PodcastFeed(
      id: id,
      title: title ?? 'Unknown Podcast',
      description: description ?? '',
      imageUrl: imageUrl,
      episodes: episodes,
      rssUrl: rssUrl,
      fetchedAt: DateTime.now(),
    );
  }

  PodcastEpisode _parseEpisode(String item, String feedTitle) {
    final title = _extractTag(item, 'title');
    final description =
        _extractTag(item, 'description') ?? _extractTag(item, 'itunes:summary');
    final audioUrl = _extractEnclosureUrl(item);
    final imageUrl = _extractImageUrl(item);
    final publishDate = _parseDate(_extractTag(item, 'pubDate'));
    final duration = _parseDuration(_extractTag(item, 'itunes:duration'));

    final guid = _extractTag(item, 'guid');
    final id = guid != null
        ? _hashUrl(guid)
        : '${feedTitle.hashCode}_${title.hashCode}';

    return PodcastEpisode(
      id: id,
      title: title ?? '',
      description: description ?? '',
      audioUrl: audioUrl ?? '',
      duration: duration,
      publishDate: publishDate,
      imageUrl: imageUrl,
    );
  }

  String? _extractTag(String xml, String tag) {
    final regex = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1)?.trim();
  }

  String? _extractEnclosureUrl(String item) {
    final match = RegExp(r'<enclosure[^>]+url="([^"]+)"').firstMatch(item);
    return match?.group(1);
  }

  /// Resolve an image url from <itunes:image href="..."/> or <image><url>...</url></image>.
  String? _extractImageUrl(String xml) {
    final itunes =
        RegExp(r'<itunes:image[^>]+href="([^"]+)"', caseSensitive: false)
            .firstMatch(xml);
    if (itunes != null) return itunes.group(1)!.trim();
    final imageBlock =
        RegExp(r'<image[^>]*>(.*?)</image>', dotAll: true).firstMatch(xml);
    if (imageBlock != null) {
      final url = _extractTag(imageBlock.group(1)!, 'url');
      if (url != null) return url;
    }
    return null;
  }

  String _prettyName(String raw) {
    final noExt = raw.contains('.')
        ? raw.substring(0, raw.lastIndexOf('.'))
        : raw;
    return noExt
        .replaceAll(RegExp(r'[-_]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _safeName(String value) =>
      value.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(
          RegExp(r'\s+'), ' ');

  String _extForUrl(String url) {
    final suffix = Uri.tryParse(url)
            ?.pathSegments
            .lastOrNull
            ?.split('?')
            .first
            .toLowerCase()
            .split('.')
            .last ??
        'mp3';
    const supported = {'flac', 'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav'};
    return supported.contains(suffix) ? suffix : 'mp3';
  }

  /// Download an episode to local storage, register it in the library and the
  /// Downloads list, and return the local file path.
  Future<String> downloadEpisode(PodcastEpisode episode,
      {required String podcastId, String? podcastTitle}) async {
    await _ensureTable();
    final db = DatabaseService.instance;
    final existing = await getLocalPath(episode.id);
    if (existing != null) {
      final file = File(existing);
      if (await file.exists()) return existing;
    }

    final dir = Directory(await StorageManager.instance.getStorageLocation());
    await dir.create(recursive: true);

    final ext = _extForUrl(episode.audioUrl);
    final safe = _safeName('${podcastTitle ?? 'Podcast'} - ${episode.title}');
    final path = '${dir.path}/$safe.$ext';

    final request = http.Request('GET', Uri.parse(episode.audioUrl))
      ..followRedirects = true
      ..headers['User-Agent'] =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    final file = File(path);
    final sink = file.openWrite();
    await response.stream.pipe(sink);
    await sink.close();

    if (await file.length() < 1000) {
      await file.delete();
      throw Exception('Downloaded file is empty');
    }

    final song = SongModel(
      id: 'podcast:${episode.id}',
      title: episode.title,
      artist: podcastTitle ?? 'Podcast',
      album: podcastTitle ?? '',
      duration: episode.duration,
      filePath: path,
      fileSize: await file.length(),
      dateAdded: DateTime.now(),
    );
    await db.insertSong(song);
    await db.upsertDownloadedTrack('podcast:${episode.id}', path);
    await db.rawInsert('''
      INSERT OR REPLACE INTO podcast_downloads (episodeId, podcastId, localPath, downloadedAt)
      VALUES (?, ?, ?, ?)
    ''', [
      episode.id,
      podcastId,
      path,
      DateTime.now().toIso8601String()
    ]);

    DownloadManager().registerExternalDownload(
      id: 'podcast:${episode.id}',
      title: episode.title,
      artist: podcastTitle ?? 'Podcast',
      album: podcastTitle,
      filePath: path,
      expectedDurationMs: episode.duration.inMilliseconds,
    );

    return path;
  }

  Future<String?> getLocalPath(String episodeId) async {
    await _ensureTable();
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
        'SELECT localPath FROM podcast_downloads WHERE episodeId = ?',
        [episodeId]);
    if (result.isEmpty) return null;
    return result.first['localPath'] as String?;
  }

  Future<bool> isDownloaded(String episodeId) async {
    final path = await getLocalPath(episodeId);
    if (path == null) return false;
    return File(path).existsSync();
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    try {
      return HttpDate.parse(dateStr);
    } catch (_) {
      return DateTime.tryParse(dateStr) ?? DateTime.now();
    }
  }

  Duration _parseDuration(String? durationStr) {
    if (durationStr == null) return Duration.zero;
    final parts = durationStr.split(':').map(int.parse).toList();
    if (parts.length == 3)
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    if (parts.length == 2)
      return Duration(minutes: parts[0], seconds: parts[1]);
    return Duration(seconds: int.tryParse(durationStr) ?? 0);
  }

  String _hashUrl(String url) => url.hashCode.toRadixString(16);

  Future<void> subscribe(PodcastFeed feed) async {
    await _ensureTable();
    final db = DatabaseService.instance;
    final maps = feed.toMap();
    maps['subscribedAt'] = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT OR REPLACE INTO podcast_subscriptions (id, title, description, imageUrl, rssUrl, episodes, fetchedAt, subscribedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      maps['id'],
      maps['title'],
      maps['description'],
      maps['imageUrl'],
      maps['rssUrl'],
      maps['episodes'],
      maps['fetchedAt'],
      maps['subscribedAt']
    ]);
  }

  Future<void> unsubscribe(String podcastId) async {
    final db = DatabaseService.instance;
    await db.rawQuery(
        'DELETE FROM podcast_subscriptions WHERE id = ?', [podcastId]);
  }

  Future<List<PodcastFeed>> getSubscriptions() async {
    await _ensureTable();
    final db = DatabaseService.instance;
    final maps = await db.rawQuery(
        'SELECT * FROM podcast_subscriptions ORDER BY subscribedAt DESC');
    return maps.map((m) => PodcastFeed.fromMap(m)).toList();
  }

  Future<void> updateFeed(PodcastFeed feed) async {
    final db = DatabaseService.instance;
    final maps = feed.toMap();
    await db.rawInsert('''
      INSERT OR REPLACE INTO podcast_subscriptions (id, title, description, imageUrl, rssUrl, episodes, fetchedAt, subscribedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, (
        SELECT subscribedAt FROM podcast_subscriptions WHERE id = ?
      ))
    ''', [
      maps['id'],
      maps['title'],
      maps['description'],
      maps['imageUrl'],
      maps['rssUrl'],
      maps['episodes'],
      maps['fetchedAt'],
      maps['id']
    ]);
  }

  Future<void> saveProgress(String episodeId, String podcastId,
      Duration position, bool completed) async {
    await _ensureTable();
    final db = DatabaseService.instance;
    await db.rawInsert('''
      INSERT OR REPLACE INTO podcast_progress (episodeId, podcastId, positionMs, completed, lastPlayedAt)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      episodeId,
      podcastId,
      position.inMilliseconds,
      completed ? 1 : 0,
      DateTime.now().toIso8601String()
    ]);
  }

  Future<Duration> getProgress(String episodeId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
        'SELECT positionMs FROM podcast_progress WHERE episodeId = ?',
        [episodeId]);
    if (result.isEmpty) return Duration.zero;
    return Duration(milliseconds: result.first['positionMs'] as int? ?? 0);
  }

  Future<bool> isCompleted(String episodeId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
        'SELECT completed FROM podcast_progress WHERE episodeId = ?',
        [episodeId]);
    if (result.isEmpty) return false;
    return (result.first['completed'] as int? ?? 0) == 1;
  }
}
