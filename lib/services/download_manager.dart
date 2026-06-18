import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'database_service.dart';
import 'lossless_resolver.dart';
import 'flac_embedder.dart';
import 'loudness_service.dart';

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
      final spotifyService = _SpotifyServiceAccess();
      final token = await spotifyService.getToken();
      if (token == null || task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'No Spotify access token';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.progress = 0.05;
      _notify();

      final detail = await LosslessResolver.getSpotifyTrackDetail(
          task.spotifyTrackId, token);
      if (detail == null || task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'Could not get track details';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.progress = 0.15;
      _notify();

      final source = await LosslessResolver.getBestSource(detail.isrc);
      if (source.isEmpty || task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'No lossless source found';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      final downloadUrl = source['url'] as String?;
      if (downloadUrl == null || task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'No download URL available';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeName = '${task.artist} - ${task.title}'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      final outputPath = '${dir.path}/downloads/$safeName.flac';
      await Directory('${dir.path}/downloads').create(recursive: true);

      task.progress = 0.25;
      _notify();

      if (task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'Cancelled';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      await LosslessResolver.downloadFLAC(
        downloadUrl,
        outputPath,
        onProgress: (p) {
          if (!task.cancelled) {
            task.progress = 0.25 + (p * 0.50);
            _notify();
          }
        },
      );

      if (task.cancelled) {
        await File(outputPath).delete();
        task.state = DownloadState.failed;
        task.error = 'Cancelled';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.filePath = outputPath;
      task.progress = 0.75;
      _notify();

      final losslessQuality =
          await db.getSetting('lossless_quality') ?? 'true';
      final embedMetadata =
          await db.getSetting('embed_metadata') ?? 'true';
      final loudnessNorm =
          await db.getSetting('loudness_norm') ?? 'false';

      if (embedMetadata == 'true' && !task.cancelled) {
        task.progress = 0.78;
        _notify();

        String? highResUrl;
        final coverResolution =
            await db.getSetting('cover_resolution') ?? 'high';
        if (coverResolution != 'low' && token != null) {
          highResUrl =
              await LosslessResolver.getHighResCoverUrl(
                  task.spotifyTrackId, token);
        }

        Uint8List? coverBytes;
        if (highResUrl != null) {
          final bytes = await LosslessResolver.fetchCoverArt(highResUrl);
          if (bytes.isNotEmpty) {
            coverBytes = Uint8List.fromList(bytes);
          }
        } else if (task.imageUrl != null) {
          final bytes = await LosslessResolver.fetchCoverArt(task.imageUrl!);
          if (bytes.isNotEmpty) {
            coverBytes = Uint8List.fromList(bytes);
          }
        }

        task.progress = 0.82;
        _notify();

        if (!task.cancelled) {
          await FlacEmbedder.embedMetadata(
            outputPath,
            title: detail.title,
            artist: detail.artist,
            album: detail.album,
            coverArt: coverBytes,
          );
        }

        task.progress = 0.88;
        _notify();
      }

      if (loudnessNorm == 'true' && !task.cancelled) {
        task.progress = 0.90;
        _notify();

        await LoudnessService.addReplayGainTags(outputPath);

        task.progress = 0.95;
        _notify();
      }

      if (!task.cancelled) {
        task.state = DownloadState.completed;
        task.progress = 1.0;
        await db.insertFailedMatch(
            'spotify:track:${task.spotifyTrackId}', outputPath);
      } else {
        await File(outputPath).delete();
        task.state = DownloadState.failed;
        task.error = 'Cancelled';
      }
    } catch (e) {
      task.state = DownloadState.failed;
      task.error = e.toString();
    }
    _notify();
    _activeDownloads--;
    _processQueue();
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
  }
}

class _SpotifyServiceAccess {
  Future<String?> getToken() async {
    final db = DatabaseService.instance;
    return db.getSetting('spotify_access_token');
  }
}
