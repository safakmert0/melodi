import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import 'database_service.dart';
import 'youtube_service.dart';
import 'metadata_service.dart';
import 'multi_source_search.dart';
import 'music_source.dart';
import 'storage_manager.dart';
import 'audio_quality_service.dart';

enum DownloadState { pending, downloading, completed, failed }

class DownloadTask {
  final String id;
  final String spotifyTrackId;
  final String? sourceVideoId;
  final String title;
  final String artist;
  final String? album;
  final String? imageUrl;
  DownloadState state;
  double progress;
  String? error;
  String? filePath;
  String requestedQuality;
  bool cancelled;

  DownloadTask({
    required this.id,
    required this.spotifyTrackId,
    this.sourceVideoId,
    required this.title,
    required this.artist,
    this.album,
    this.imageUrl,
    this.state = DownloadState.pending,
    this.progress = 0,
    this.error,
    this.filePath,
    this.requestedQuality = 'high',
    this.cancelled = false,
  });
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._();
  factory DownloadManager() => _instance;
  DownloadManager._();

  final List<DownloadTask> _tasks = [];
  int _activeDownloads = 0;
  static const int _maxParallel = 8;
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();
  final YouTubeService _youtubeService = YouTubeService();
  final MultiSourceSearch _multiSource = MultiSourceSearch();

  /// Callback when a download completes - triggers library refresh
  VoidCallback? onDownloadComplete;

  Stream<List<DownloadTask>> get taskStream => _controller.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  String _taskId() =>
      'dl_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';

  void addTask({
    required String spotifyTrackId,
    required String title,
    required String artist,
    String? album,
    String? imageUrl,
    String? sourceVideoId,
  }) {
    final task = DownloadTask(
      id: _taskId(),
      spotifyTrackId: spotifyTrackId,
      sourceVideoId: sourceVideoId,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
    );
    _tasks.add(task);
    _processQueue();
    _notify();
  }

  void addTasks(List<Map<String, String>> tracks) {
    for (final t in tracks) {
      addTask(
        spotifyTrackId: t['id']!,
        title: t['title']!,
        artist: t['artist']!,
        album: t['album'],
        imageUrl: t['imageUrl'],
      );
    }
  }

  Future<void> _processQueue() async {
    while (_activeDownloads < _maxParallel) {
      final pending =
          _tasks.where((t) => t.state == DownloadState.pending).toList();
      if (pending.isEmpty) break;
      _activeDownloads++;
      _downloadTrack(pending.first);
    }
  }

  Future<void> _downloadTrack(DownloadTask task) async {
    task.state = DownloadState.downloading;
    _notify();
    try {
      final db = DatabaseService.instance;
      task.requestedQuality = await AudioQualityService().getDownloadQuality();
      final downloadDir =
          Directory(await StorageManager.instance.getStorageLocation());
      await downloadDir.create(recursive: true);

      // Try full-track sources first. Deezer catalogue entries are deliberately
      // excluded because its public URL is only a 30-second preview.
      task.progress = 0.05;
      task.error = 'Kaynaklar aranıyor...';
      _notify();

      final query = '${task.artist} - ${task.title}';
      String? streamUrl;

      // Search all sources in parallel
      final allTracks =
          await _multiSource.searchAllSync(query, limitPerSource: 3);
      if (allTracks.isNotEmpty) {
        // JioSaavn can expose a full media URL. YouTube is handled separately
        // by YouTubeService so throttling/signature changes are supported.
        final priorityOrder = [
          MusicSourceType.jiosaavn,
        ];
        for (final sourceType in priorityOrder) {
          final sourceTracks =
              allTracks.where((t) => t.source == sourceType).toList();
          if (sourceTracks.isEmpty) continue;
          for (final track in sourceTracks.take(2)) {
            if (task.cancelled) break;
            try {
              task.progress = 0.1;
              task.error = '${track.sourceLabel} deneniyor...';
              _notify();
              final url = await _multiSource.getStreamUrl(track);
              if (url != null && url.isNotEmpty) {
                streamUrl = url;
                break;
              }
            } catch (_) {}
          }
          if (streamUrl != null) break;
        }
      }

      // For YouTube tracks, use YouTube service download (handles throttling)
      if (streamUrl == null && !task.cancelled) {
        // Find YouTube track from search results
        final ytTracks = allTracks
            .where((t) => t.source == MusicSourceType.youtube)
            .toList();
        String? videoId = task.sourceVideoId;
        if (videoId == null && ytTracks.isNotEmpty) {
          videoId = ytTracks.first.id;
        } else if (videoId == null) {
          // Fallback: search YouTube directly
          task.progress = 0.1;
          task.error = 'YouTube aranıyor...';
          _notify();
          final videos = await _youtubeService.search(query);
          if (videos.isNotEmpty) {
            final exactMatch = videos
                .where((v) =>
                    v.title.toLowerCase().contains(task.title.toLowerCase()) &&
                    v.author.toLowerCase().contains(task.artist
                        .toLowerCase()
                        .split(',')
                        .first
                        .trim()
                        .toLowerCase()))
                .toList();
            videoId =
                (exactMatch.isNotEmpty ? exactMatch.first : videos.first).id;
          }
        }

        if (videoId != null) {
          task.progress = 0.15;
          task.error = 'YouTube indiriliyor...';
          _notify();
          // Use YouTube service which handles throttling properly
          final resultPath = await _youtubeService.downloadAudio(
            videoId,
            task.title,
            quality: task.requestedQuality,
            destinationDirectory: downloadDir.path,
          );
          if (resultPath != null) {
            task.filePath = resultPath;
            task.progress = 0.8;
            _notify();

            if (!task.cancelled) {
              final importedPath =
                  await _importDownloadedFile(resultPath, task);
              if (importedPath != null) {
                task.filePath = importedPath;
                task.state = DownloadState.completed;
                task.progress = 1.0;
                task.error = null;
                await db.upsertDownloadedTrack(
                    task.spotifyTrackId, importedPath);
                onDownloadComplete?.call();
              } else {
                final downloadedFile = File(resultPath);
                if (await downloadedFile.exists()) {
                  task.filePath = resultPath;
                  task.state = DownloadState.completed;
                  task.progress = 1.0;
                  task.error = null;
                  await db.upsertDownloadedTrack(
                      task.spotifyTrackId, resultPath);
                  onDownloadComplete?.call();
                } else {
                  task.state = DownloadState.failed;
                  task.error = 'İndirilen dosya bulunamadı';
                }
              }
            }
            _notify();
            _activeDownloads--;
            _processQueue();
            return;
          }
        }
      }

      if (streamUrl == null || task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'Eşleşen şarkı bulunamadı';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.progress = 0.3;
      _notify();

      // Download from stream URL
      var resultPath =
          await _downloadFromUrl(streamUrl, task.title, downloadDir);

      // A provider URL can expire or reject a direct request. Fall back to the
      // dedicated YouTube downloader before marking the task as failed.
      if (resultPath == null && !task.cancelled) {
        resultPath = await _downloadFromYouTube(
          task: task,
          searchResults: allTracks,
          query: query,
        );
      }

      if (resultPath == null || task.cancelled) {
        if (task.cancelled) {
          task.state = DownloadState.failed;
          task.error = 'İptal edildi';
        } else {
          task.state = DownloadState.failed;
          task.error = 'İndirme başarısız';
        }
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.filePath = resultPath;
      task.progress = 0.8;
      _notify();

      if (!task.cancelled) {
        final importedPath = await _importDownloadedFile(resultPath, task);
        if (importedPath != null) {
          task.filePath = importedPath;
          task.state = DownloadState.completed;
          task.progress = 1.0;
          task.error = null;
          await db.upsertDownloadedTrack(task.spotifyTrackId, importedPath);
          onDownloadComplete?.call();
        } else {
          final downloadedFile = File(resultPath);
          if (await downloadedFile.exists()) {
            task.filePath = resultPath;
            task.state = DownloadState.completed;
            task.progress = 1.0;
            task.error = null;
            await db.upsertDownloadedTrack(task.spotifyTrackId, resultPath);
            onDownloadComplete?.call();
          } else {
            task.state = DownloadState.failed;
            task.error = 'İndirilen dosya bulunamadı';
          }
        }
      } else {
        task.state = DownloadState.failed;
        task.error = 'İptal edildi';
      }
    } catch (e) {
      task.state = DownloadState.failed;
      task.error = e.toString();
    }
    _notify();
    _activeDownloads--;
    _processQueue();
  }

  Future<String?> _downloadFromYouTube({
    required DownloadTask task,
    required List<OnlineTrack> searchResults,
    required String query,
  }) async {
    try {
      final ytTracks = searchResults
          .where((track) => track.source == MusicSourceType.youtube)
          .toList();
      String? videoId = task.sourceVideoId;
      videoId ??= ytTracks.isEmpty ? null : ytTracks.first.id;
      if (videoId == null) {
        task.progress = 0.15;
        task.error = 'YouTube yedek kaynağı aranıyor...';
        _notify();
        final videos = await _youtubeService.search(query);
        if (videos.isNotEmpty) {
          final title = task.title.toLowerCase();
          final artist = task.artist.toLowerCase().split(',').first.trim();
          final exact = videos.where((video) {
            final videoTitle = video.title.toLowerCase();
            final author = video.author.toLowerCase();
            return videoTitle.contains(title) &&
                (artist.isEmpty ||
                    author.contains(artist) ||
                    videoTitle.contains(artist));
          }).toList();
          videoId = (exact.isNotEmpty ? exact.first : videos.first).id;
        }
      }
      if (videoId == null || task.cancelled) return null;
      task.progress = 0.2;
      task.error = 'YouTube yedek kaynağından indiriliyor...';
      _notify();
      return _youtubeService.downloadAudio(
        videoId,
        task.title,
        quality: task.requestedQuality,
        destinationDirectory:
            await StorageManager.instance.getStorageLocation(),
      );
    } catch (error) {
      debugPrint('YouTube fallback download error: $error');
      return null;
    }
  }

  Future<String?> _downloadFromUrl(
      String url, String title, Directory dir) async {
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      String safeTitle = sanitized.isEmpty ? 'download' : sanitized;
      final filePath =
          '${dir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(filePath);
      if (await file.exists()) return filePath;

      final client = HttpClient()
        ..userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
        ..connectionTimeout = const Duration(seconds: 120);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
        final response = await request.close();
        if (response.statusCode != 200) {
          return null;
        }
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.close();
        final len = await file.length();
        if (len < 1000) {
          await file.delete();
          return null;
        }
        return filePath;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Download from URL error: $e');
      return null;
    }
  }

  Future<String?> _importDownloadedFile(
      String filePath, DownloadTask task) async {
    try {
      final db = DatabaseService.instance;
      final musicDir =
          Directory(await StorageManager.instance.getStorageLocation());
      await musicDir.create(recursive: true);

      final ext = filePath.split('.').last;
      final safeName = '${task.artist} - ${task.title}'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      var destPath = '${musicDir.path}/$safeName.$ext';
      var counter = 1;
      while (File(destPath).existsSync()) {
        destPath = '${musicDir.path}/$safeName ($counter).$ext';
        counter++;
      }

      await File(filePath).rename(destPath);

      final metadata = await MetadataService.extractMetadata(destPath);
      if (metadata != null) {
        final placeholderId = 'spotify:${task.spotifyTrackId}';
        SongModel? placeholder = await db.getSongById(placeholderId);
        if (placeholder == null) {
          final titleKey = _matchKey(task.title);
          final artistKey = _matchKey(task.artist.split(',').first);
          for (final candidate in await db.getAllSongs()) {
            if (!candidate.filePath.startsWith('spotify://')) continue;
            final sameTitle = _matchKey(candidate.title) == titleKey;
            final candidateArtist =
                _matchKey(candidate.artist.split(',').first);
            final sameArtist = artistKey.isEmpty ||
                candidateArtist.contains(artistKey) ||
                artistKey.contains(candidateArtist);
            if (sameTitle && sameArtist) {
              placeholder = candidate;
              break;
            }
          }
        }
        final normalized = metadata.copyWith(
          id: placeholder?.id ?? metadata.id,
          title: task.title,
          artist: task.artist,
          album:
              (task.album?.isNotEmpty ?? false) ? task.album : metadata.album,
          filePath: destPath,
          albumArt: placeholder?.albumArt ?? metadata.albumArt,
          fileSize: await File(destPath).length(),
        );
        await db.insertSong(normalized);
      }

      return destPath;
    } catch (e) {
      debugPrint('Import downloaded file error: $e');
      return null;
    }
  }

  String _matchKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void cancelTask(String taskId) {
    final tasks = _tasks.where((t) => t.id == taskId).toList();
    if (tasks.isNotEmpty) {
      tasks.first.cancelled = true;
      if (tasks.first.state == DownloadState.pending) {
        tasks.first.state = DownloadState.failed;
        tasks.first.error = 'Cancelled';
        _notify();
      }
    }
  }

  void cancelAll() {
    for (final task in _tasks) {
      task.cancelled = true;
      if (task.state == DownloadState.pending) {
        task.state = DownloadState.failed;
        task.error = 'Cancelled';
      }
    }
    _notify();
  }

  void retryTask(String taskId) {
    final task = _tasks
        .where((t) => t.id == taskId && t.state == DownloadState.failed)
        .toList();
    if (task.isNotEmpty) {
      task.first.state = DownloadState.pending;
      task.first.error = null;
      task.first.progress = 0;
      task.first.cancelled = false;
      _processQueue();
      _notify();
    }
  }

  void retryAllFailed() {
    for (final task in _tasks) {
      if (task.state == DownloadState.failed) {
        task.state = DownloadState.pending;
        task.error = null;
        task.progress = 0;
        task.cancelled = false;
      }
    }
    _processQueue();
    _notify();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.state == DownloadState.completed);
    _notify();
  }

  void clearFailed() {
    _tasks.removeWhere((t) => t.state == DownloadState.failed);
    _notify();
  }

  void clearTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    _tasks.removeWhere((task) =>
        ids.contains(task.id) &&
        (task.state == DownloadState.completed ||
            task.state == DownloadState.failed));
    _notify();
  }

  void _notify() {
    _controller.add(List.from(_tasks));
  }

  void dispose() {
    _controller.close();
    _youtubeService.dispose();
    _multiSource.dispose();
  }
}
