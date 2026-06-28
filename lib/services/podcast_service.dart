import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_service.dart';

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
    publishDate: DateTime.tryParse(map['publishDate'] as String? ?? '') ?? DateTime.now(),
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
      fetchedAt: DateTime.tryParse(map['fetchedAt'] as String? ?? '') ?? DateTime.now(),
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
  }

  Future<PodcastFeed> fetchFeed(String rssUrl) async {
    final response = await _client.get(Uri.parse(rssUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch podcast feed: ${response.statusCode}');
    }
    return _parseRss(response.body, rssUrl);
  }

  PodcastFeed _parseRss(String xml, String rssUrl) {
    final channelMatch = RegExp(r'<channel>(.*?)</channel>', dotAll: true).firstMatch(xml);
    if (channelMatch == null) throw FormatException('Invalid RSS: no channel element');

    final channel = channelMatch.group(1)!;
    final title = _extractTag(channel, 'title');
    final description = _extractTag(channel, 'description') ?? _extractTag(channel, 'itunes:summary');
    final imageUrl = _extractTag(channel, 'itunes:image') ?? _extractTag(channel, 'image');

    final items = RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(channel);
    final episodes = items.map((m) => _parseEpisode(m.group(1)!, title)).toList();

    final id = _hashUrl(rssUrl);

    return PodcastFeed(
      id: id,
      title: title,
      description: description ?? '',
      imageUrl: imageUrl,
      episodes: episodes,
      rssUrl: rssUrl,
      fetchedAt: DateTime.now(),
    );
  }

  PodcastEpisode _parseEpisode(String item, String feedTitle) {
    final title = _extractTag(item, 'title');
    final description = _extractTag(item, 'description') ?? _extractTag(item, 'itunes:summary');
    final audioUrl = _extractEnclosureUrl(item);
    final imageUrl = _extractTag(item, 'itunes:image');
    final publishDate = _parseDate(_extractTag(item, 'pubDate'));
    final duration = _parseDuration(_extractTag(item, 'itunes:duration'));

    final guid = _extractTag(item, 'guid');
    final id = guid != null ? _hashUrl(guid) : '${feedTitle.hashCode}_${title.hashCode}';

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
    if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
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
    ''', [maps['id'], maps['title'], maps['description'], maps['imageUrl'], maps['rssUrl'], maps['episodes'], maps['fetchedAt'], maps['subscribedAt']]);
  }

  Future<void> unsubscribe(String podcastId) async {
    final db = DatabaseService.instance;
    await db.rawQuery('DELETE FROM podcast_subscriptions WHERE id = ?', [podcastId]);
  }

  Future<List<PodcastFeed>> getSubscriptions() async {
    await _ensureTable();
    final db = DatabaseService.instance;
    final maps = await db.rawQuery('SELECT * FROM podcast_subscriptions ORDER BY subscribedAt DESC');
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
    ''', [maps['id'], maps['title'], maps['description'], maps['imageUrl'], maps['rssUrl'], maps['episodes'], maps['fetchedAt'], maps['id']]);
  }

  Future<void> saveProgress(String episodeId, String podcastId, Duration position, bool completed) async {
    await _ensureTable();
    final db = DatabaseService.instance;
    await db.rawInsert('''
      INSERT OR REPLACE INTO podcast_progress (episodeId, podcastId, positionMs, completed, lastPlayedAt)
      VALUES (?, ?, ?, ?, ?)
    ''', [episodeId, podcastId, position.inMilliseconds, completed ? 1 : 0, DateTime.now().toIso8601String()]);
  }

  Future<Duration> getProgress(String episodeId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery('SELECT positionMs FROM podcast_progress WHERE episodeId = ?', [episodeId]);
    if (result.isEmpty) return Duration.zero;
    return Duration(milliseconds: result.first['positionMs'] as int? ?? 0);
  }

  Future<bool> isCompleted(String episodeId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery('SELECT completed FROM podcast_progress WHERE episodeId = ?', [episodeId]);
    if (result.isEmpty) return false;
    return (result.first['completed'] as int? ?? 0) == 1;
  }
}
