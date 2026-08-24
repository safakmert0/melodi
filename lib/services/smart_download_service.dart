import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'download_manager.dart';
import 'multi_source_search.dart'
import 'spotify_service.dart';
import 'audio_quality_service.dart';
import 'storage_manager.dart';

enum SmartDownloadType {
  likedSongs,
  weeklyMix,
  releaseRadar,
  discoverWeekly,
  playlist,
  artist,
  album,
}

class SmartDownloadRule {
  final String id;
  final SmartDownloadType type;
  final String? sourceId;
  final bool enabled;
  final bool wifiOnly;
  final bool chargingOnly;
  final bool nightOnly;
  final int maxDownloads;
  final DateTime? lastRun;
  final Map<String, dynamic> config;

  const SmartDownloadRule({
    required this.id,
    required this.type,
    this.sourceId,
    this.enabled = true,
    this.wifiOnly = true,
    this.chargingOnly = false,
    this.nightOnly = false,
    this.maxDownloads = 50,
    this.lastRun,
    this.config = const {},
  });

  SmartDownloadRule copyWith({
    String? id,
    SmartDownloadType? type,
    String? sourceId,
    bool? enabled,
    bool? wifiOnly,
    bool? chargingOnly,
    bool? nightOnly,
    int? maxDownloads,
    DateTime? lastRun,
    Map<String, dynamic>? config,
  }) {
    return SmartDownloadRule(
      id: id ?? this.id,
      type: type ?? this.type,
      sourceId: sourceId ?? this.sourceId,
      enabled: enabled ?? this.enabled,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      chargingOnly: chargingOnly ?? this.chargingOnly,
      nightOnly: nightOnly ?? this.nightOnly,
      maxDownloads: maxDownloads ?? this.maxDownloads,
      lastRun: lastRun ?? this.lastRun,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'sourceId': sourceId,
    'enabled': enabled,
    'wifiOnly': wifiOnly,
    'chargingOnly': chargingOnly,
    'nightOnly': nightOnly,
    'maxDownloads': maxDownloads,
    'lastRun': lastRun?.toIso8601String(),
    'config': config,
  };

  factory SmartDownloadRule.fromJson(Map<String, dynamic> json) => SmartDownloadRule(
    id: json['id'] as String,
    type: SmartDownloadType.values[json['type'] as int],
    sourceId: json['sourceId'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    wifiOnly: json['wifiOnly'] as bool? ?? true,
    chargingOnly: json['chargingOnly'] as bool? ?? false,
    nightOnly: json['nightOnly'] as bool? ?? false,
    maxDownloads: json['maxDownloads'] as int? ?? 50,
    lastRun: json['lastRun'] != null
        ? DateTime.parse(json['lastRun'] as String)
        : null,
    config: json['config'] as Map<String, dynamic>? ?? {},
  );
}

class SmartDownloadService {
  SmartDownloadService._();
  static final SmartDownloadService _instance = SmartDownloadService._();
  factory SmartDownloadService() => _instance;
  static SmartDownloadService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;
  final DownloadManager _downloadManager = DownloadManager();
  final MultiSourceSearch _multiSource = MultiSourceSearch();
  final AudioQualityService _qualityService = AudioQualityService();

  final StreamController<List<SmartDownloadRule>> _rulesController =
      StreamController<List<SmartDownloadRule>>.broadcast();
  final StreamController<SmartDownloadProgress> _progressController =
      StreamController<SmartDownloadProgress>.broadcast();

  List<SmartDownloadRule> _rules = [];
  Timer? _schedulerTimer;
  bool _isRunning = false;

  Stream<List<SmartDownloadRule>> get rulesStream => _rulesController.stream;
  Stream<SmartDownloadProgress> get progressStream => _progressController.stream;
  List<SmartDownloadRule> get rules => List.unmodifiable(_rules);
  bool get isRunning => _isRunning;

  static const String _rulesKey = 'smart_download_rules';
  static const String _lastCleanupKey = 'smart_download_last_cleanup';

  Future<void> initialize() async {
    await _loadRules();
    _startScheduler();
  }

  Future<void> _loadRules() async {
    try {
      final raw = await _db.getSetting(_rulesKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _rules = list.map((e) => SmartDownloadRule.fromJson(e)).toList();
      } else {
        _rules = _defaultRules();
        await _saveRules();
      }
    } catch (_) {
      _rules = _defaultRules();
      await _saveRules();
    }
    _rulesController.add(List.from(_rules));
  }

  List<SmartDownloadRule> _defaultRules() => [
    SmartDownloadRule(
      id: 'liked_songs',
      type: SmartDownloadType.likedSongs,
      enabled: false,
      wifiOnly: true,
      nightOnly: true,
      maxDownloads: 100,
    ),
    SmartDownloadRule(
      id: 'weekly_mix',
      type: SmartDownloadType.weeklyMix,
      enabled: false,
      wifiOnly: true,
      nightOnly: true,
      maxDownloads: 30,
    ),
  ];

  Future<void> _saveRules() async {
    await _db.setSetting(_rulesKey, jsonEncode(_rules.map((r) => r.toJson()).toList()));
    _rulesController.add(List.from(_rules));
  }

  void _startScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkAndRunRules();
    });
    _checkAndRunRules();
  }

  Future<void> _checkAndRunRules() async {
    if (_isRunning) return;

    final now = DateTime.now();
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (!_shouldRunNow(rule, now)) continue;
      if (rule.lastRun != null &&
          now.difference(rule.lastRun!).inHours < 6) continue;

      await _runRule(rule);
    }
  }

  bool _shouldRunNow(SmartDownloadRule rule, DateTime now) {
    if (rule.wifiOnly) {
      // TODO: Check connectivity_plus for WiFi
    }
    if (rule.chargingOnly) {
      // TODO: Check battery state
    }
    if (rule.nightOnly) {
      final hour = now.hour;
      if (hour < 22 || hour > 6) return false;
    }
    return true;
  }

  Future<void> _runRule(SmartDownloadRule rule) async {
    _isRunning = true;
    _progressController.add(SmartDownloadProgress(
      ruleId: rule.id,
      status: 'Başlatılıyor...',
      current: 0,
      total: 0,
    ));

    try {
      switch (rule.type) {
        case SmartDownloadType.likedSongs:
          await _downloadLikedSongs(rule);
          break;
        case SmartDownloadType.weeklyMix:
          await _downloadWeeklyMix(rule);
          break;
        case SmartDownloadType.releaseRadar:
          await _downloadReleaseRadar(rule);
          break;
        case SmartDownloadType.discoverWeekly:
          await _downloadDiscoverWeekly(rule);
          break;
        case SmartDownloadType.playlist:
          await _downloadPlaylist(rule);
          break;
        case SmartDownloadType.artist:
          await _downloadArtist(rule);
          break;
        case SmartDownloadType.album:
          await _downloadAlbum(rule);
          break;
      }

      _rules = _rules.map((r) {
        if (r.id == rule.id) return r.copyWith(lastRun: DateTime.now());
        return r;
      }).toList();
      await _saveRules();
    } catch (e) {
      debugPrint('Smart download rule ${rule.id} failed: $e');
      _progressController.add(SmartDownloadProgress(
        ruleId: rule.id,
        status: 'Hata: $e',
        current: 0,
        total: 0,
        error: e.toString(),
      ));
    } finally {
      _isRunning = false;
      _progressController.add(SmartDownloadProgress(
        ruleId: rule.id,
        status: 'Tamamlandı',
        current: 0,
        total: 0,
      ));
    }
  }

  Future<void> _downloadLikedSongs(SmartDownloadRule rule) async {
    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    _progressController.add(SmartDownloadProgress(
      ruleId: rule.id,
      status: 'Beğenilen şarkılar alınıyor...',
      current: 0,
      total: 0,
    ));

    final tracks = await spotify.getSavedTracks(limit: rule.maxDownloads);
    _progressController.add(SmartDownloadProgress(
      ruleId: rule.id,
      status: '${tracks.length} şarkı bulundu, indiriliyor...',
      current: 0,
      total: tracks.length,
    ));

    for (var i = 0; i < tracks.length; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = tracks[i];
      _progressController.add(SmartDownloadProgress(
        ruleId: rule.id,
        status: '${track['name']} - ${track['artists'][0]['name']}',
        current: i + 1,
        total: tracks.length,
      ));

      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: track['album']['name'],
        imageUrl: track['album']['images'].isNotEmpty
            ? track['album']['images'][0]['url']
            : null,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _downloadWeeklyMix(SmartDownloadRule rule) async {
    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    _progressController.add(SmartDownloadProgress(
      ruleId: rule.id,
      status: 'Weekly Mix alınıyor...',
      current: 0,
      total: 0,
    ));

    final playlists = await spotify.getUserPlaylists();
    final weeklyMix = playlists.firstWhere(
      (p) => (p['name'] as String).toLowerCase().contains('weekly mix'),
      orElse: () => <String, dynamic>{},
    );

    if (weeklyMix.isEmpty) return;

    final tracks = await spotify.getPlaylistTracks(weeklyMix['id'], limit: rule.maxDownloads);
    _progressController.add(SmartDownloadProgress(
      ruleId: rule.id,
      status: '${tracks.length} şarkı bulundu, indiriliyor...',
      current: 0,
      total: tracks.length,
    ));

    for (var i = 0; i < tracks.length; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = tracks[i]['track'];
      if (track == null) continue;

      _progressController.add(SmartDownloadProgress(
        ruleId: rule.id,
        status: '${track['name']} - ${track['artists'][0]['name']}',
        current: i + 1,
        total: tracks.length,
      ));

      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: track['album']['name'],
        imageUrl: track['album']['images'].isNotEmpty
            ? track['album']['images'][0]['url']
            : null,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _downloadReleaseRadar(SmartDownloadRule rule) async {
    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    final playlists = await spotify.getUserPlaylists();
    final releaseRadar = playlists.firstWhere(
      (p) => (p['name'] as String).toLowerCase().contains('release radar'),
      orElse: () => <String, dynamic>{},
    );

    if (releaseRadar.isEmpty) return;

    final tracks = await spotify.getPlaylistTracks(releaseRadar['id'], limit: rule.maxDownloads);
    for (var i = 0; i < tracks.length; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = tracks[i]['track'];
      if (track == null) continue;

      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: track['album']['name'],
        imageUrl: track['album']['images'].isNotEmpty
            ? track['album']['images'][0]['url']
            : null,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _downloadDiscoverWeekly(SmartDownloadRule rule) async {
    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    final playlists = await spotify.getUserPlaylists();
    final discover = playlists.firstWhere(
      (p) => (p['name'] as String).toLowerCase().contains('discover weekly'),
      orElse: () => <String, dynamic>{},
    );

    if (discover.isEmpty) return;

    final tracks = await spotify.getPlaylistTracks(discover['id'], limit: rule.maxDownloads);
    for (var i = 0; i < tracks.length; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = tracks[i]['track'];
      if (track == null) continue;

      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: track['album']['name'],
        imageUrl: track['album']['images'].isNotEmpty
            ? track['album']['images'][0]['url']
            : null,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _downloadPlaylist(SmartDownloadRule rule) async {
    if (rule.sourceId == null) return;

    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    final tracks = await spotify.getPlaylistTracks(rule.sourceId!, limit: rule.maxDownloads);
    for (var i = 0; i < tracks.length; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = tracks[i]['track'];
      if (track == null) continue;

      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: track['album']['name'],
        imageUrl: track['album']['images'].isNotEmpty
            ? track['album']['images'][0]['url']
            : null,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _downloadArtist(SmartDownloadRule rule) async {
    if (rule.sourceId == null) return;

    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    final topTracks = await spotify.getArtistTopTracks(rule.sourceId!);
    for (var i = 0; i < topTracks.length && i < rule.maxDownloads; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = topTracks[i];
      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: track['album']['name'],
        imageUrl: track['album']['images'].isNotEmpty
            ? track['album']['images'][0]['url']
            : null,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _downloadAlbum(SmartDownloadRule rule) async {
    if (rule.sourceId == null) return;

    final spotify = SpotifyService();
    if (!await spotify.isConnected()) return;

    final tracks = await spotify.getAlbumTracks(rule.sourceId!);
    for (var i = 0; i < tracks.length && i < rule.maxDownloads; i++) {
      if (!_rules.any((r) => r.id == rule.id && r.enabled)) break;

      final track = tracks[i];
      _downloadManager.addTask(
        spotifyTrackId: track['id'],
        title: track['name'],
        artist: track['artists'].map((a) => a['name']).join(', '),
        album: rule.config['albumName'] as String?,
        imageUrl: rule.config['imageUrl'] as String?,
        expectedDurationMs: track['duration_ms'],
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> addRule(SmartDownloadRule rule) async {
    _rules.add(rule);
    await _saveRules();
  }

  Future<void> updateRule(SmartDownloadRule rule) async {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
      await _saveRules();
    }
  }

  Future<void> removeRule(String ruleId) async {
    _rules.removeWhere((r) => r.id == ruleId);
    await _saveRules();
  }

  Future<void> toggleRule(String ruleId, bool enabled) async {
    final index = _rules.indexWhere((r) => r.id == ruleId);
    if (index >= 0) {
      _rules[index] = _rules[index].copyWith(enabled: enabled);
      await _saveRules();
    }
  }

  Future<void> runRuleNow(String ruleId) async {
    final rule = _rules.firstWhere((r) => r.id == ruleId, orElse: () => null);
    if (rule != null) {
      await _runRule(rule);
    }
  }

  Future<void> cleanupOldDownloads({int maxAgeDays = 30, int maxCount = 500}) async {
    final now = DateTime.now();
    final db = DatabaseService.instance;
    final allSongs = await db.getAllSongs();

    final downloadedSongs = allSongs
        .where((s) => s.filePath.isNotEmpty && !s.filePath.startsWith('spotify://'))
        .toList();

    downloadedSongs.sort((a, b) {
      final aTime = a.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    var removed = 0;
    for (final song in downloadedSongs) {
      if (removed >= maxCount) break;

      final age = now.difference(song.lastPlayed ?? now).inDays;
      final playCount = song.playCount ?? 0;

      if (age > maxAgeDays && playCount == 0) {
        try {
          final file = File(song.filePath);
          if (await file.exists()) {
            await file.delete();
            await db.deleteSong(song.id);
            removed++;
          }
        } catch (_) {}
      }
    }

    final lastCleanup = now.toIso8601String();
    await _db.setSetting(_lastCleanupKey, lastCleanup);
    debugPrint('Smart download cleanup: removed $removed old files');
  }

  void dispose() {
    _schedulerTimer?.cancel();
    _rulesController.close();
    _progressController.close();
  }
}

class SmartDownloadProgress {
  final String ruleId;
  final String status;
  final int current;
  final int total;
  final String? error;

  const SmartDownloadProgress({
    required this.ruleId,
    required this.status,
    required this.current,
    required this.total,
    this.error,
  });

  double get progress => total > 0 ? current / total : 0.0;
}