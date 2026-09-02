import 'dart:convert';
import 'dart:io';
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

  factory LibraryHealthIssue.fromMap(Map<String, dynamic> map) =>
      LibraryHealthIssue(
        id: map['id'] as String,
        category: map['category'] as String,
        description: map['description'] as String,
        severity: map['severity'] as String,
        autoFixable: (map['autoFixable'] as int?) == 1,
        data: (map['data'] as String?) != null
            ? jsonDecode(map['data'] as String) as Map<String, dynamic>
            : {},
      );
}

/// The outcome of attempting to fix a single detected issue.
class FixDetail {
  final String issueId;
  final String category;
  final String description;
  final bool success;
  final String? reason;

  const FixDetail({
    required this.issueId,
    required this.category,
    required this.description,
    required this.success,
    this.reason,
  });
}

/// A collection of per-issue fix outcomes produced by a remediation run.
class LibraryHealthFixResult {
  final List<FixDetail> details;

  LibraryHealthFixResult([List<FixDetail>? details]) : details = details ?? [];

  int get fixedCount => details.where((d) => d.success).length;
  int get failedCount => details.where((d) => !d.success).length;
  bool get hasResults => details.isNotEmpty;

  void add(FixDetail detail) => details.add(detail);
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

  Future<void> scanLibrary({bool force = false}) async {
    if (_isScanning) return;
    _isScanning = true;

    final cached = force ? null : await _getCachedScan();
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

    final missingFileIssues = await _scanMissingFiles(allSongs);
    issues.addAll(missingFileIssues);

    _issues = issues;
    _lastScanAt = DateTime.now();
    _isScanning = false;

    await _cacheScanResults(issues);
  }

  Future<List<LibraryHealthIssue>> _scanMissingArt(
      List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final missing = await _db.getTracksMissingArt();
    if (missing.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'missing_art_summary',
      category: 'Album Art',
      description: '${missing.length} tracks missing album art',
      severity: missing.length > 20
          ? 'error'
          : missing.length > 5
              ? 'warning'
              : 'info',
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
        data: {
          'trackId': trackId,
          'title': track['title'],
          'artist': track['artist']
        },
      ));
    }

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanMissingMetadata(
      List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final missing = await _db.getTracksMissingMetadata();
    if (missing.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'missing_metadata_summary',
      category: 'Metadata',
      description: '${missing.length} tracks with incomplete metadata',
      severity: missing.length > 20
          ? 'error'
          : missing.length > 5
              ? 'warning'
              : 'info',
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
    final failed = manager.tasks
        .where((t) => t.state == DownloadState.failed && !t.cancelled)
        .toList();

    if (failed.isNotEmpty) {
      issues.add(LibraryHealthIssue(
        id: 'failed_downloads_summary',
        category: 'Downloads',
        description: '${failed.length} downloads failed',
        severity: 'error',
        autoFixable: true,
        data: {
          'count': failed.length,
          'tracks': failed
              .map((t) => {
                    'taskId': t.id,
                    'title': t.title,
                    'artist': t.artist,
                    'error': t.error,
                  })
              .toList()
        },
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
    final groups = groupBy(songs,
        (SongModel s) => '${s.title.toLowerCase()}|${s.artist.toLowerCase()}');

    for (final entry in groups.entries) {
      if (entry.value.length > 1) {
        final track = entry.value.first;
        issues.add(LibraryHealthIssue(
          id: 'duplicate_${track.id}',
          category: 'Duplicates',
          description:
              '${track.title} by ${track.artist} (${entry.value.length} copies)',
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
      data: {
        'count': lowConf.length,
        'tracks': lowConf
            .map((e) => {
                  'spotifyId': e.key,
                  'confidence': e.value,
                })
            .toList()
      },
    ));

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanOrphaned(List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final downloadedTracks = await _db.getDownloadedTracks();
    final songPaths = songs.map((s) => s.filePath).toSet();

    final orphaned = downloadedTracks.where((t) {
      final path = t['filePath'] as String?;
      return path != null &&
          !songPaths.contains(path) &&
          File(path).existsSync();
    }).toList();

    if (orphaned.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'orphaned_summary',
      category: 'Orphaned',
      description: '${orphaned.length} orphaned files',
      severity: 'warning',
      autoFixable: false,
      data: {
        'count': orphaned.length,
        'files': orphaned
            .map((t) => {
                  'path': t['filePath'],
                  'trackId': t['spotifyTrackId'],
                })
            .toList()
      },
    ));

    return issues;
  }

  Future<List<LibraryHealthIssue>> _scanMissingFiles(
      List<SongModel> songs) async {
    final issues = <LibraryHealthIssue>[];
    final missing = <Map<String, dynamic>>[];
    final trackIds = <String>[];
    final paths = <String>[];

    for (final song in songs) {
      if (song.filePath.isEmpty || song.filePath.startsWith('spotify://')) {
        continue;
      }
      if (!File(song.filePath).existsSync()) {
        missing.add({
          'id': song.id,
          'title': song.title,
          'artist': song.artist,
          'path': song.filePath,
        });
        trackIds.add(song.id);
        paths.add(song.filePath);
      }
    }

    if (missing.isEmpty) return issues;

    issues.add(LibraryHealthIssue(
      id: 'missing_files_summary',
      category: 'Missing Files',
      description:
          '${missing.length} tracks point to files that no longer exist',
      severity: 'error',
      autoFixable: true,
      data: {
        'count': missing.length,
        'tracks': missing,
        'trackIds': trackIds,
        'paths': paths,
      },
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

  /// Fix a single issue by id and return a detailed result describing what
  /// happened. Returns null if the issue is unknown.
  Future<LibraryHealthFixResult?> fixIssue(String issueId) async {
    final matches = _issues.where((issue) => issue.id == issueId).toList();
    if (matches.isEmpty) return null;

    final result = LibraryHealthFixResult();
    final dedupe = <String>{};
    final details = await _resolveIssue(matches.first, dedupe);
    for (final detail in details) {
      result.add(detail);
    }

    await invalidateCache();
    await scanLibrary(force: true);
    return result;
  }

  /// Run remediation for every detected issue and return a detailed,
  /// per-issue report of what was fixed and what could not be.
  Future<LibraryHealthFixResult> fixAllIssues() async {
    final result = LibraryHealthFixResult();
    final dedupe = <String>{};
    final snapshot = List<LibraryHealthIssue>.from(_issues);

    for (final issue in snapshot) {
      final details = await _resolveIssue(issue, dedupe);
      for (final detail in details) {
        result.add(detail);
      }
    }

    await invalidateCache();
    await scanLibrary(force: true);
    return result;
  }

  Future<List<FixDetail>> _resolveIssue(
      LibraryHealthIssue issue, Set<String> dedupeAlbumArt) async {
    try {
      switch (issue.category) {
        case 'Album Art':
          final tracks = issue.data['tracks'] as List<dynamic>?;
          if (tracks != null) {
            final out = <FixDetail>[];
            for (final raw in tracks) {
              final t = raw as Map<String, dynamic>;
              final id = t['id'] as String;
              if (!dedupeAlbumArt.add(id)) continue;
              out.add(await _fixAlbumArt(id,
                  '${t['title']} by ${t['artist']}'));
            }
            return out;
          }
          final singleId = issue.data['trackId'] as String?;
          if (singleId != null) {
            if (!dedupeAlbumArt.add(singleId)) return [];
            return [
              await _fixAlbumArt(singleId, issue.description)
            ];
          }
          return [_fail(issue, 'No track reference')];

        case 'Metadata':
          final tracks = issue.data['tracks'] as List<dynamic>?;
          if (tracks != null) {
            final out = <FixDetail>[];
            for (final raw in tracks) {
              final t = raw as Map<String, dynamic>;
              out.add(await _fixMetadata(
                  t['id'] as String, '${t['title']} by ${t['artist']}'));
            }
            return out;
          }
          return [_fail(issue, 'No track reference')];

        case 'Downloads':
          final tracks = issue.data['tracks'] as List<dynamic>?;
          if (tracks != null) {
            final out = <FixDetail>[];
            final retried = <String>{};
            for (final raw in tracks) {
              final t = raw as Map<String, dynamic>;
              final taskId = t['taskId'] as String?;
              if (taskId == null || !retried.add(taskId)) continue;
              final label = t['title'] as String? ?? 'download';
              try {
                DownloadManager().retryTask(taskId);
                out.add(FixDetail(
                  issueId: issue.id,
                  category: issue.category,
                  description: label,
                  success: true,
                  reason: 'Re-queued for download',
                ));
              } catch (e) {
                out.add(FixDetail(
                  issueId: issue.id,
                  category: issue.category,
                  description: label,
                  success: false,
                  reason: 'Could not retry: $e',
                ));
              }
            }
            return out;
          }
          return [_fail(issue, 'No download reference')];

        case 'Matching':
          final tracks = issue.data['tracks'] as List<dynamic>?;
          if (tracks != null) {
            final out = <FixDetail>[];
            for (final raw in tracks) {
              final t = raw as Map<String, dynamic>;
              if (t.containsKey('spotifyId')) {
                out.add(await _clearLowConfidence(t['spotifyId'] as String));
              } else if (t.containsKey('spotifyTrackId')) {
                out.add(
                    await _resolveWrongMatch(t['spotifyTrackId'] as String));
              }
            }
            return out;
          }
          return [_fail(issue, 'No match reference')];

        case 'Duplicates':
          final trackIds = (issue.data['trackIds'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          return [await _fixDuplicate(trackIds, issue.description)];

        case 'Orphaned':
          final files = issue.data['files'] as List<dynamic>?;
          if (files != null) {
            final out = <FixDetail>[];
            for (final raw in files) {
              final f = raw as Map<String, dynamic>;
              out.add(await _fixOrphaned(
                f['path'] as String?,
                f['path'] as String? ?? 'orphaned file',
              ));
            }
            return out;
          }
          return [_fail(issue, 'No file reference')];

        case 'Missing Files':
          final trackIds = (issue.data['trackIds'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          final paths = (issue.data['paths'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          final out = <FixDetail>[];
          for (var i = 0; i < trackIds.length; i++) {
            out.add(await _fixMissingFile(
                trackIds[i], i < paths.length ? paths[i] : ''));
          }
          return out;

        case 'Blocked':
          final tracks = issue.data['tracks'] as List<dynamic>?;
          if (tracks != null) {
            final out = <FixDetail>[];
            for (final raw in tracks) {
              final t = raw as Map<String, dynamic>;
              out.add(await _unblockTrack(
                t['trackId'] as String,
                '${t['title']} by ${t['artist']}',
              ));
            }
            return out;
          }
          return [_fail(issue, 'No track reference')];

        default:
          return [_fail(issue, 'No remediation available')];
      }
    } catch (e) {
      return [
        FixDetail(
          issueId: issue.id,
          category: issue.category,
          description: issue.description,
          success: false,
          reason: 'Unexpected error: $e',
        )
      ];
    }
  }

  FixDetail _fail(LibraryHealthIssue issue, String reason) => FixDetail(
        issueId: issue.id,
        category: issue.category,
        description: issue.description,
        success: false,
        reason: reason,
      );

  Future<FixDetail> _fixAlbumArt(String trackId, String label) async {
    final url = await MetadataService.getHighResAlbumArt(trackId);
    if (url != null && url.isNotEmpty) {
      await _db.updateTrackImageUrl(trackId, url);
      return FixDetail(
        issueId: 'missing_art_$trackId',
        category: 'Album Art',
        description: label,
        success: true,
        reason: 'Cover art updated',
      );
    }
    return FixDetail(
      issueId: 'missing_art_$trackId',
      category: 'Album Art',
      description: label,
      success: false,
      reason:
          'No cover art source available (connect Spotify to fetch artwork)',
    );
  }

  Future<FixDetail> _fixMetadata(String trackId, String label) async {
    final song = await _db.getSongById(trackId);
    if (song == null) {
      return FixDetail(
        issueId: 'metadata_$trackId',
        category: 'Metadata',
        description: label,
        success: false,
        reason: 'Track no longer exists in library',
      );
    }
    if (song.filePath.isEmpty || song.filePath.startsWith('spotify://')) {
      return FixDetail(
        issueId: 'metadata_$trackId',
        category: 'Metadata',
        description: label,
        success: false,
        reason: 'Cannot read local metadata for a streaming track',
      );
    }
    final file = File(song.filePath);
    if (!await file.exists()) {
      return FixDetail(
        issueId: 'metadata_$trackId',
        category: 'Metadata',
        description: label,
        success: false,
        reason: 'Source file missing at ${song.filePath}',
      );
    }
    final meta = await MetadataService.extractMetadata(song.filePath);
    if (meta == null) {
      return FixDetail(
        issueId: 'metadata_$trackId',
        category: 'Metadata',
        description: label,
        success: false,
        reason: 'Could not read metadata from file',
      );
    }
    final updates = <String, dynamic>{};
    if ((song.album.isEmpty || song.album == 'Unknown Album') &&
        meta.album.isNotEmpty) {
      updates['album'] = meta.album;
    }
    if ((song.artist.isEmpty || song.artist == 'Unknown Artist') &&
        meta.artist.isNotEmpty) {
      updates['artist'] = meta.artist;
    }
    if (song.duration.inMilliseconds == 0 && meta.duration.inMilliseconds != 0) {
      updates['durationMs'] = meta.duration.inMilliseconds;
    }
    if ((song.title.isEmpty) && meta.title.isNotEmpty) {
      updates['title'] = meta.title;
    }
    if (updates.isEmpty) {
      return FixDetail(
        issueId: 'metadata_$trackId',
        category: 'Metadata',
        description: label,
        success: false,
        reason: 'File metadata still incomplete',
      );
    }
    await _db.updateTrackMetadata(trackId, updates);
    return FixDetail(
      issueId: 'metadata_$trackId',
      category: 'Metadata',
      description: label,
      success: true,
      reason: 'Updated: ${updates.keys.join(', ')}',
    );
  }

  Future<FixDetail> _resolveWrongMatch(String spotifyTrackId) async {
    await _db.resolveWrongMatch(spotifyTrackId);
    await _db.rawDelete(
        'DELETE FROM track_match_cache WHERE spotifyId = ?',
        [spotifyTrackId]);
    return FixDetail(
      issueId: 'wrong_$spotifyTrackId',
      category: 'Matching',
      description: 'Wrong match ($spotifyTrackId)',
      success: true,
      reason: 'Bad match cleared; track is open for re-matching',
    );
  }

  Future<FixDetail> _clearLowConfidence(String spotifyId) async {
    await _db.rawDelete(
        'DELETE FROM track_match_cache WHERE spotifyId = ?', [spotifyId]);
    return FixDetail(
      issueId: 'low_conf_$spotifyId',
      category: 'Matching',
      description: 'Low confidence match ($spotifyId)',
      success: true,
      reason: 'Low-confidence match cleared; will be re-matched',
    );
  }

  Future<FixDetail> _fixDuplicate(List<String> trackIds, String label) async {
    if (trackIds.length < 2) {
      return FixDetail(
        issueId: 'duplicate',
        category: 'Duplicates',
        description: label,
        success: false,
        reason: 'Not enough tracks to merge',
      );
    }
    final keep = trackIds.first;
    int removed = 0;
    for (final id in trackIds.skip(1)) {
      try {
        final song = await _db.getSongById(id);
        if (song != null &&
            song.filePath.isNotEmpty &&
            !song.filePath.startsWith('spotify://')) {
          final f = File(song.filePath);
          if (await f.exists()) await f.delete();
        }
        await _db.deleteSong(id);
        removed++;
      } catch (_) {
        // best-effort: continue with the next duplicate
      }
    }
    if (removed == trackIds.length - 1) {
      return FixDetail(
        issueId: 'duplicate_$keep',
        category: 'Duplicates',
        description: label,
        success: true,
        reason: 'Removed $removed duplicate(s), kept the original',
      );
    } else if (removed > 0) {
      return FixDetail(
        issueId: 'duplicate_$keep',
        category: 'Duplicates',
        description: label,
        success: true,
        reason:
            'Removed $removed of ${trackIds.length - 1} duplicates (some could not be deleted)',
      );
    }
    return FixDetail(
      issueId: 'duplicate_$keep',
      category: 'Duplicates',
      description: label,
      success: false,
      reason: 'Could not remove duplicate files',
    );
  }

  Future<FixDetail> _fixOrphaned(String? path, String label) async {
    if (path == null || path.isEmpty) {
      return FixDetail(
        issueId: 'orphaned',
        category: 'Orphaned',
        description: label,
        success: false,
        reason: 'No file path recorded',
      );
    }
    var clearedFile = false;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        clearedFile = true;
      } else {
        clearedFile = true;
      }
    } catch (_) {
      clearedFile = false;
    }
    try {
      await _db.rawDelete(
          'DELETE FROM downloaded_tracks WHERE filePath = ?', [path]);
    } catch (_) {}

    return FixDetail(
      issueId: 'orphaned_$path',
      category: 'Orphaned',
      description: label,
      success: clearedFile,
      reason: clearedFile
          ? 'Removed orphaned file and its download record'
          : 'Could not delete orphaned file at $path',
    );
  }

  Future<FixDetail> _fixMissingFile(String trackId, String path) async {
    try {
      await _db.deleteSong(trackId);
      return FixDetail(
        issueId: 'missing_file_$trackId',
        category: 'Missing Files',
        description: path.isNotEmpty ? path : trackId,
        success: true,
        reason: 'Removed library entry pointing to a missing file',
      );
    } catch (e) {
      return FixDetail(
        issueId: 'missing_file_$trackId',
        category: 'Missing Files',
        description: path.isNotEmpty ? path : trackId,
        success: false,
        reason: 'Could not remove entry: $e',
      );
    }
  }

  Future<FixDetail> _unblockTrack(String trackId, String label) async {
    try {
      await _db
          .rawDelete('DELETE FROM blocked_tracks WHERE trackId = ?', [trackId]);
      return FixDetail(
        issueId: 'blocked_$trackId',
        category: 'Blocked',
        description: label,
        success: true,
        reason: 'Track unblocked',
      );
    } catch (e) {
      return FixDetail(
        issueId: 'blocked_$trackId',
        category: 'Blocked',
        description: label,
        success: false,
        reason: 'Could not unblock: $e',
      );
    }
  }

  int getFixableCount() {
    return _issues.where((i) => i.autoFixable).length;
  }

  Future<void> _cacheScanResults(List<LibraryHealthIssue> issues) async {
    final data = issues.map((i) => i.toMap()).toList();
    await _db.setSetting('library_health_cache', jsonEncode(data));
    await _db.setSetting(
        'library_health_cached_at', DateTime.now().toIso8601String());
  }

  Future<List<LibraryHealthIssue>?> _getCachedScan() async {
    final cachedAtStr = await _db.getSetting('library_health_cached_at');
    if (cachedAtStr == null) return null;

    final cachedAt = DateTime.tryParse(cachedAtStr);
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt) > _cacheDuration) {
      return null;
    }

    final data = await _db.getSetting('library_health_cache');
    if (data == null) return null;

    final list = jsonDecode(data) as List<dynamic>;
    return list
        .map((e) => LibraryHealthIssue.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> invalidateCache() async {
    _issues = [];
    _lastScanAt = null;
    await _db.setSetting('library_health_cache', '');
    await _db.setSetting('library_health_cached_at', '');
  }
}
