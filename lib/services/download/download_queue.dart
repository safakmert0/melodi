import 'package:background_downloader/background_downloader.dart' as bg;
import 'dart:async';

import '../music_source.dart';

/// Download task representing a single track download
class DownloadTask {
  final String id;
  final OnlineTrack track;
  final String streamUrl;
  final String filePath;
  final String quality;
  DownloadStatus status;
  double progress;
  int downloadedBytes;
  int totalBytes;
  String? error;

  DownloadTask({
    required this.id,
    required this.track,
    required this.streamUrl,
    required this.filePath,
    required this.quality,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'track': track.toJson(),
        'streamUrl': streamUrl,
        'filePath': filePath,
        'quality': quality,
        'status': status.name,
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'error': error,
      };

  static DownloadTask fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      track: OnlineTrack.fromJson(json['track'] as Map<String, dynamic>),
      streamUrl: json['streamUrl'] as String,
      filePath: json['filePath'] as String,
      quality: json['quality'] as String,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

enum DownloadStatus {
  pending,
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download queue manager for audio-only downloads
/// Uses background_downloader (iOS URLSession) for background downloads
class DownloadQueue {
  final List<DownloadTask> _tasks = [];

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();
  List<DownloadTask> get failedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.failed).toList();

  /// Add a new download task
  void addTask(DownloadTask task) {
    _tasks.add(task);
    _notify();
  }

  /// Add multiple tasks
  void addTasks(List<DownloadTask> tasks) {
    _tasks.addAll(tasks);
    _notify();
  }

  /// Remove a task
  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _notify();
  }

  /// Start a download task
  Future<void> startTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => throw ArgumentError('Task not found'));
    if (task.status == DownloadStatus.downloading) return;

    task.status = DownloadStatus.downloading;
    _notify();

    try {
      final bgTask = bg.DownloadTask(
        url: task.streamUrl,
        filename: task.filePath,
        baseDirectory: bg.BaseDirectory.applicationDocuments,
        directory: 'Melodi/Offline',
        retries: 2,
        metaData: task.id,
      );

      final result = await bg.FileDownloader().download(
        bgTask,
        onProgress: (p) {
          task.progress = p.clamp(0.0, 1.0);
          _notify();
        },
      ).timeout(const Duration(minutes: 15), onTimeout: () => throw TimeoutException('Download timeout'));

      if (result.status == bg.TaskStatus.complete) {
        final path = await bgTask.filePath();
        if (path != null && path.isNotEmpty) {
          task.status = DownloadStatus.completed;
          task.progress = 1.0;
        } else {
          task.status = DownloadStatus.failed;
          task.error = 'Download completed but file not found';
        }
      } else {
        task.status = DownloadStatus.failed;
        task.error = 'Download failed: ${result.status}';
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
    } finally {
      _notify();
    }
  }

  /// Retry a failed download
  Future<void> retryTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id);
    task.status = DownloadStatus.pending;
    task.error = null;
    task.progress = 0.0;
    task.downloadedBytes = 0;
    await startTask(id);
  }

  /// Clear completed tasks
  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    _notify();
  }

  /// Clear failed tasks
  void clearFailed() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.failed);
    _notify();
  }

  void _notify() {
    // Notify listeners if needed
  }

  void dispose() {
    // No active tasks to clean up in this simplified version
  }
}

/// Singleton instance
final downloadQueue = DownloadQueue();