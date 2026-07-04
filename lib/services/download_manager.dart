import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'database_service.dart';
import 'youtube_service.dart';
import 'metadata_service.dart';
import 'multi_source_search.dart';
import 'music_source.dart';
import 'youtube_audio_source.dart';

enum DownloadState { pending, downloading, completed, failed }

class DownloadTask {
  final String id;
  final String spotifyTrackId;
  final String title;
  final String artist;
  final String? album;
  final String? imageUrl;
  DownloadState state;
  double progress;
  String? error;
  String? filePath;
  bool cancelled;

  DownloadTask({
    required this.id,
    required this.spotifyTrackId,
    required this.title,
    required this.artist,
    this.album,
    this.imageUrl,
    this.state = DownloadState.pending,
    this.progress = 0,
    this.error,
    this.filePath,
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
  final StreamController<List<DownloadTask>> _controller = StreamController<List<DownloadTask>>.broadcast();
  final YouTubeService _youtubeService = YouTubeService();
  final MultiSourceSearch _multiSource = MultiSourceSearch();

  Stream<List<DownloadTask>> get taskStream => _controller.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  String _taskId() => 'dl_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';

  void addTask({
    required String spotifyTrackId,
    required String title,
    required String artist,
    String? album,
    String? imageUrl,
  }) {
    final task = DownloadTask(
      id: _taskId(),
      spotifyTrackId: spotifyTrackId,
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
      final pending = _tasks.where((t) => t.state == DownloadState.pending).toList();
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
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads');
      await downloadDir.create(recursive: true);

      // Try multi-source search first (JioSaavn, Deezer, etc.)
      task.progress = 0.05;
      task.error = 'Kaynaklar aranıyor...';
      _notify();

      final query = '${task.artist} - ${task.title}';
      OnlineTrack? bestTrack;
      String? streamUrl;

      // Search all sources in parallel
      final allTracks = await _multiSource.searchAllSync(query, limitPerSource: 3);
      if (allTracks.isNotEmpty) {
        // Prioritize: JioSaavn > Deezer > YouTube (direct download)
        final priorityOrder = [
          MusicSourceType.jiosaavn,
          MusicSourceType.deezer,
        ];
        for (final sourceType in priorityOrder) {
          final sourceTracks = allTracks.where((t) => t.source == sourceType).toList();
          if (sourceTracks.isEmpty) continue;
          for (final track in sourceTracks.take(2)) {
            if (task.cancelled) break;
            try {
              task.progress = 0.1;
              task.error = '${track.sourceLabel} deneniyor...';
              _notify();
              final url = await _multiSource.getStreamUrl(track);
              if (url != null && url.isNotEmpty) {
                bestTrack = track;
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
        final ytTracks = allTracks.where((t) => t.source == MusicSourceType.youtube).toList();
        String? videoId;
        if (ytTracks.isNotEmpty) {
          videoId = ytTracks.first.id;
        } else {
          // Fallback: search YouTube directly
          task.progress = 0.1;
          task.error = 'YouTube aranıyor...';
          _notify();
          final videos = await _youtubeService.search(query);
          if (videos.isNotEmpty) {
            final exactMatch = videos.where((v) =>
                v.title.toLowerCase().contains(task.title.toLowerCase()) &&
                v.author.toLowerCase().contains(task.artist.toLowerCase().split(',').first.trim().toLowerCase())
            ).toList();
            videoId = (exactMatch.isNotEmpty ? exactMatch.first : videos.first).id;
          }
        }

        if (videoId != null) {
          task.progress = 0.15;
          task.error = 'YouTube indiriliyor...';
          _notify();
          // Use YouTube service which handles throttling properly
          final resultPath = await _youtubeService.downloadAudio(videoId, task.title);
          if (resultPath != null) {
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
                await db.insertFailedMatch(task.spotifyTrackId, importedPath);
              } else {
                task.state = DownloadState.completed;
                task.progress = 1.0;
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
      final resultPath = await _downloadFromUrl(streamUrl, task.title, downloadDir);

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
          await db.insertFailedMatch(task.spotifyTrackId, importedPath);
        } else {
          task.state = DownloadState.completed;
          task.progress = 1.0;
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

  Future<String?> _downloadFromUrl(String url, String title, Directory dir) async {
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      String safeTitle = sanitized.isEmpty ? 'download' : sanitized;
      final filePath = '${dir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(filePath);
      if (await file.exists()) return filePath;

      final client = HttpClient()
        ..userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
        ..connectionTimeout = const Duration(seconds: 120);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
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

  Future<String?> _importDownloadedFile(String filePath, DownloadTask task) async {
    try {
      final db = DatabaseService.instance;
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/music');
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
        await db.insertSong(metadata);
      }

      return destPath;
    } catch (e) {
      debugPrint('Import downloaded file error: $e');
      return null;
    }
  }

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
    final task = _tasks.where((t) => t.id == taskId && t.state == DownloadState.failed).toList();
    if (task.isNotEmpty) {
      task.first.state = DownloadState.pending;
      task.first.error = null;
      task.first.progress = 0;
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

  void _notify() {
    _controller.add(List.from(_tasks));
  }

  void dispose() {
    _controller.close();
    _youtubeService.dispose();
    _multiSource.dispose();
  }
}
