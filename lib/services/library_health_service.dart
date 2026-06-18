import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../models/song_model.dart';
import 'database_service.dart';
import 'download_manager.dart';
import 'metadata_service.dart';

class LibraryHealthIssue {
  final String id;
  final String category;
  final String description;
  final String severity;
  final bool autoFixable;
  final Map<String, dynamic> data;

  const LibraryHealthIssue({
    required this.id,
    required this.category,
    required this.description,
    required this.severity,
    this.autoFixable = false,
    this.data = const {},
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'description': description,
    'severity': severity,
    'autoFixable': autoFixable ? 1 : 0,
    'data': jsonEncode(data),
  };

  factory LibraryHealthIssue.fromMap(Map<String, dynamic> map) => LibraryHealthIssue(
    id: map['id'] as String,
    category: map['category'] as String,
    description: map['description'] as String,
    severity: map['severity'] as String,
    autoFixable: (map['autoFixable'] as int?) == 1,
    data: (map['data'] as String?) != null ? jsonDecode(map['data'] as String) as Map<String, dynamic> : {},
  );
}

class LibraryHealthService {
  static final LibraryHealthService _instance = LibraryHealthService._();
  factory LibraryHealthService() => _instance;
  LibraryHealthService._();

  static DatabaseService get _db => DatabaseService.instance;

  List<LibraryHealthIssue> _issues = [];
  DateTime? _lastScanAt;
  bool _isScanning = false;

  List<LibraryHealthIssue> get issues => List.unmodifiable(_issues);
  DateTime? get lastScanAt => _lastScanAt;
  bool get isScanning => _isScanning;

  static const Duration _cacheDuration = Duration(hours: 1);

  Future<void> scanLibrary() async {
    if (_isScanning) return;
    _isScanning = true;

    final cached = await _getCachedScan();
    if (cached != null) {
      _issues = cached;
      _lastScanAt = DateTime.now();
      _isScanning = false;
      return;
    }

    final issues = <LibraryHealthIssue>[];
    final allSongs = await _db.getAllSongs();

    final missingArtIssues = await _scanMissingArt(allSongs);
    issues.addAll(missingArtIssues);

    final missingMetadataIssues = await _scanMissingMetadata(allSongs);
    issues.addAll(missingMetadataIssues);

    final wrongMatchIssues = await _scanWrongMatches();
    issues.addAll(wrongMatchIssues);

    final failedDownloadIssues = await _scanFailedDownloads();
    issues.addAll(failedDownloadIssues);

    final blockedIssues = await _scanBlocked();
    issues.addAll(blockedIssues);

    final duplicateIssues = _scanDuplicates(allSongs);
    issues.addAll(duplicateIssues);

    final lowConfidenceIssues = await _scanLowConfidence();
    issues.addAll(lowConfidenceIssues);

    final orphanedIssues = await _scanOrphaned(allSongs);
    issues.addAll(orphanedIssues);

    _issues = issues;
    _lastScanAt = DateTime.now();
    _isScanning = false;

    await _cacheScanResults(issues);
  }

  Future<List<LibraryHealthIssue>> _scanMissingArt(List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final missing = await _db.getTracksMissingArt();
    if (missing.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'missing_art_summary',
      category: 'Album Art',
      description: '${missing.length} tracks missing album art',
      severity: missing.length > 20 ? 'error' : missing.length > 5 ? 'warning' : 'info',
      autoFixable: true,
      data: {'count': missing.length, 'tracks': missing},
    ));

    for (final track in missing) {
      final trackId = track['id'] as String;
      issues.add(LibraryHealthIssue(
        id: 'missing_art_$trackId',
        category: 'Album Art',
        description: '${track['title']} by ${track['artist']}',
        severity: 'info',
        autoFixable: true,
        data: {'trackId': trackId, 'title': track['title'], 'artist': track['artist']},
      ));
    }

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanMissingMetadata(List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final missing = await _db.getTracksMissingMetadata();
    if (missing.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'missing_metadata_summary',
      category: 'Metadata',
      description: '${missing.length} tracks with incomplete metadata',
      severity: missing.length > 20 ? 'error' : missing.length > 5 ? 'warning' : 'info',
      autoFixable: true,
      data: {'count': missing.length, 'tracks': missing},
    ));

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanWrongMatches() async {
    final issues = <LibraryHealthIssue>[];
    final wrongMatches = await _db.getWrongMatches(resolved: false);
    if (wrongMatches.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'wrong_matches_summary',
      category: 'Matching',
      description: '${wrongMatches.length} tracks with wrong matches',
      severity: 'error',
      autoFixable: false,
      data: {'count': wrongMatches.length, 'tracks': wrongMatches},
    ));

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanFailedDownloads() async {
    final issues = <LibraryHealthIssue>[];
    final manager = DownloadManager();
    final failed = manager.tasks.where((t) => t.state == DownloadState.failed && !t.cancelled).toList();

    if (failed.isNotEmpty) {
      issues.add(LibraryHealthIssue(
        id: 'failed_downloads_summary',
        category: 'Downloads',
        description: '${failed.length} downloads failed',
        severity: 'error',
        autoFixable: true,
        data: {'count': failed.length, 'tracks': failed.map((t) => {
          'taskId': t.id,
          'title': t.title,
          'artist': t.artist,
          'error': t.error,
        }).toList()},
      ));
    }

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanBlocked() async {
    final issues = <LibraryHealthIssue>[];
    final db = await _db.database;
    final blocked = await db.query('blocked_tracks');
    if (blocked.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'blocked_summary',
      category: 'Blocked',
      description: '${blocked.length} blocked tracks',
      severity: 'warning',
      autoFixable: false,
      data: {'count': blocked.length, 'tracks': blocked},
    ));

    return issues;
  }

  List<LibraryHealthIssue> _scanDuplicates(List<SongModel> songs) {
    final issues = <LibraryHealthIssue>[];
    final groups = groupBy(songs, (SongModel s) => '${s.title.toLowerCase()}|${s.artist.toLowerCase()}');

    for (final entry in groups.entries) {
      if (entry.value.length > 1) {
        final track = entry.value.first;
        issues.add(LibraryHealthIssue(
          id: 'duplicate_${track.id}',
          category: 'Duplicates',
          description: '${track.title} by ${track.artist} (${entry.value.length} copies)',
          severity: 'warning',
          autoFixable: false,
          data: {
            'title': track.title,
            'artist': track.artist,
            'count': entry.value.length,
            'trackIds': entry.value.map((s) => s.id).toList(),
          },
        ));
      }
    }

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanLowConfidence() async {
    final issues = <LibraryHealthIssue>[];
    final confidences = await _db.getAllCachedConfidences();
    final lowConf = confidences.entries.where((e) => e.value < 0.5).toList();

    if (lowConf.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'low_confidence_summary',
      category: 'Matching',
      description: '${lowConf.length} tracks with low match confidence',
      severity: 'warning',
      autoFixable: false,
      data: {'count': lowConf.length, 'tracks': lowConf.map((e) => {
        'spotifyId': e.key,
        'confidence': e.value,
      }).toList()},
    ));

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanOrphaned(List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final downloadedTracks = await _db.getDownloadedTracks();
    final songPaths = songs.map((s) => s.filePath).toSet();

    final orphaned = downloadedTracks.where((t) {
      final path = t['filePath'] as String?;
      return path != null && !songPaths.contains(path) && File(path).existsSync();
    }).toList();

    if (orphaned.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'orphaned_summary',
      category: 'Orphaned',
      description: '${orphaned.length} orphaned files',
      severity: 'warning',
      autoFixable: false,
      data: {'count': orphaned.length, 'files': orphaned.map((t) => {
        'path': t['filePath'],
        'trackId': t['spotifyTrackId'],
      }).toList()},
    ));

    return issues;
  }

  double getHealthScore() {
    if (_issues.isEmpty) return 100.0;

    double deductions = 0;
    for (final issue in _issues) {
      if (issue.id.endsWith('_summary')) continue;
      switch (issue.severity) {
        case 'error':
          deductions += 15;
        case 'warning':
          deductions += 5;
        case 'info':
          deductions += 2;
      }
    }

    return (100 - deductions).clamp(0, 100);
  }

  Map<String, List<Map<String, dynamic>>> getIssuesByCategory() {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final issue in _issues) {
      result.putIfAbsent(issue.category, () => []).add(issue.toMap());
    }
    return result;
  }

  Future<bool> fixIssue(String issueId) async {
    final issue = _issues.where((i) => i.id == issueId).toList();
    if (issue.isEmpty || !issue.first.autoFixable) return false;

    final iss = issue.first;

    if (iss.category == 'Album Art' && iss.data.containsKey('trackId')) {
      await MetadataService.backfillAlbumArt();
      _issues.remove(iss);
      return true;
    }

    if (iss.category == 'Metadata') {
      await MetadataService.backfillTrackMetadata();
      _issues.remove(iss);
      return true;
    }

    if (iss.category == 'Downloads' && iss.data.containsKey('tracks')) {
      final tracks = iss.data['tracks'] as List<dynamic>;
      for (final t in tracks) {
        final taskId = (t as Map<String, dynamic>)['taskId'] as String?;
        if (taskId != null) {
          DownloadManager().retryTask(taskId);
        }
      }
      _issues.remove(iss);
      return true;
    }

    return false;
  }

  Future<int> fixAllIssues() async {
    int fixed = 0;
    final fixable = _issues.where((i) => i.autoFixable).toList();
    for (final issue in fixable) {
      final success = await fixIssue(issue.id);
      if (success) fixed++;
    }
    return fixed;
  }

  int getFixableCount() {
    return _issues.where((i) => i.autoFixable).length;
  }

  Future<void> _cacheScanResults(List<LibraryHealthIssue> issues) async {
    final data = issues.map((i) => i.toMap()).toList();
    await _db.setSetting('library_health_cache', jsonEncode(data));
    await _db.setSetting('library_health_cached_at', DateTime.now().toIso8601String());
  }

  Future<List<LibraryHealthIssue>?> _getCachedScan() async {
    final cachedAtStr = await _db.getSetting('library_health_cached_at');
    if (cachedAtStr == null) return null;

    final cachedAt = DateTime.tryParse(cachedAtStr);
    if (cachedAt == null || DateTime.now().difference(cachedAt) > _cacheDuration) return null;

    final data = await _db.getSetting('library_health_cache');
    if (data == null) return null;

    final list = jsonDecode(data) as List<dynamic>;
    return list.map((e) => LibraryHealthIssue.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> invalidateCache() async {
    _issues = [];
    _lastScanAt = null;
    await _db.setSetting('library_health_cache', '');
    await _db.setSetting('library_health_cached_at', '');
  }
}
