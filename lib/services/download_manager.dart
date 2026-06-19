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
import 'youtube_service.dart';
import 'metadata_service.dart';

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

      bool losslessAttempted = false;

      if (task.spotifyTrackId.isNotEmpty &&
          task.spotifyTrackId != 'youtube' &&
          task.spotifyTrackId != 'local') {
        losslessAttempted = true;
        final spotifyService = _SpotifyServiceAccess();
        final token = await spotifyService.getToken();

        if (token != null && !task.cancelled) {
          task.progress = 0.05;
          _notify();

          final detail = await LosslessResolver.getSpotifyTrackDetail(
              task.spotifyTrackId, token);
          if (detail != null && !task.cancelled) {
            task.progress = 0.15;
            _notify();

            final source = await LosslessResolver.getBestSource(detail.isrc);
            if (source.isNotEmpty && !task.cancelled) {
              final downloadUrl = source['url'] as String?;
              if (downloadUrl != null && !task.cancelled) {
                task.progress = 0.25;
                _notify();

                final safeName = '${task.artist} - ${task.title}'
                    .replaceAll(RegExp(r'[^\w\s-]'), '')
                    .replaceAll(RegExp(r'\s+'), ' ');
                final flacPath = '${downloadDir.path}/$safeName.flac';

                await LosslessResolver.downloadFLAC(
                  downloadUrl,
                  flacPath,
                  onProgress: (p) {
                    if (!task.cancelled) {
                      task.progress = 0.25 + (p * 0.50);
                      _notify();
                    }
                  },
                );

                if (!task.cancelled) {
                  task.filePath = flacPath;
                  task.progress = 0.75;
                  _notify();

                  final embedMetadata =
                      await db.getSetting('embed_metadata') ?? 'true';
                  final loudnessNorm =
                      await db.getSetting('loudness_norm') ?? 'false';

                  if (embedMetadata == 'true' && !task.cancelled) {
                    task.progress = 0.78;
                    _notify();

                    String? coverUrl;
                    final coverResolution =
                        await db.getSetting('cover_resolution') ?? 'high';
                    if (coverResolution != 'low' && token != null) {
                      coverUrl = await LosslessResolver.getHighResCoverUrl(
                          task.spotifyTrackId, token);
                    }

                    Uint8List? coverBytes;
                    final coverSrc = coverUrl ?? task.imageUrl;
                    if (coverSrc != null) {
                      final bytes = await LosslessResolver.fetchCoverArt(coverSrc);
                      if (bytes.isNotEmpty) coverBytes = Uint8List.fromList(bytes);
                    }

                    if (!task.cancelled) {
                      await FlacEmbedder.embedMetadata(
                        flacPath,
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
                    await LoudnessService.addReplayGainTags(flacPath);
                    task.progress = 0.95;
                    _notify();
                  }

                  if (!task.cancelled) {
                    task.state = DownloadState.completed;
                    task.progress = 1.0;
                    await db.insertFailedMatch(
                        'spotify:track:${task.spotifyTrackId}', flacPath);
                    await _importDownloadedFile(flacPath, task);
                    _notify();
                    _activeDownloads--;
                    _processQueue();
                    return;
                  }
                }
              }
            }
          }
        }
      }

      if (!task.cancelled && task.state != DownloadState.completed) {
        task.progress = 0.1;
        task.error = losslessAttempted ? 'Lossless kaynak bulunamadı, YouTube deneniyor...' : 'YouTube aranıyor...';
        _notify();

        final query = '${task.artist} - ${task.title}';
        final videos = await _youtubeService.search(query);

        String? videoId;
        if (videos.isNotEmpty) {
          final exactMatch = videos.where((v) =>
              v.title.toLowerCase().contains(task.title.toLowerCase()) &&
              v.author.toLowerCase().contains(task.artist.toLowerCase().split(',').first.trim().toLowerCase())
          ).toList();
          videoId = (exactMatch.isNotEmpty ? exactMatch.first : videos.first).id;
        }

        if (videoId == null || task.cancelled) {
          task.state = DownloadState.failed;
          task.error = 'YouTube\'da eşleşen video bulunamadı';
          _notify();
          _activeDownloads--;
          _processQueue();
          return;
        }

        task.progress = 0.3;
        _notify();

        final resultPath = await _youtubeService.downloadAudio(videoId, task.title);

        if (resultPath == null || task.cancelled) {
          if (task.cancelled) {
            task.state = DownloadState.failed;
            task.error = 'İptal edildi';
          } else {
            task.state = DownloadState.failed;
            task.error = 'YouTube indirme başarısız';
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
            final sourceLabel = losslessAttempted ? 'YouTube (lossless kaynak yoktu)' : 'YouTube';
            await db.insertFailedMatch(task.spotifyTrackId, importedPath);
          } else {
            task.state = DownloadState.completed;
            task.progress = 1.0;
          }
        } else {
          task.state = DownloadState.failed;
          task.error = 'İptal edildi';
        }
      }
    } catch (e) {
      task.state = DownloadState.failed;
      task.error = e.toString();
    }
    _notify();
    _activeDownloads--;
    _processQueue();
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
  }
}

class _SpotifyServiceAccess {
  Future<String?> getToken() async {
    final db = DatabaseService.instance;
    return db.getSetting('spotify_access_token');
  }
}
