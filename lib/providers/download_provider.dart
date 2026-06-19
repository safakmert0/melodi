import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/download_manager.dart';
import '../services/notification_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadManager _manager = DownloadManager();
  StreamSubscription<List<DownloadTask>>? _subscription;

  List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => _tasks;
  List<String> _notifiedCompleted = [];
  List<String> _notifiedFailed = [];

  List<DownloadTask> get activeDownloads =>
      _tasks.where((t) => t.state == DownloadState.downloading || t.state == DownloadState.pending).toList();

  List<DownloadTask> get completedDownloads =>
      _tasks.where((t) => t.state == DownloadState.completed).toList();

  List<DownloadTask> get failedDownloads =>
      _tasks.where((t) => t.state == DownloadState.failed).toList();

  bool get isDownloading => activeDownloads.isNotEmpty;
  int get totalCount => _tasks.length;
  int get activeCount => activeDownloads.length;
  int get completedCount => completedDownloads.length;
  int get failedCount => failedDownloads.length;

  DownloadProvider() {
    _subscription = _manager.taskStream.listen((tasks) {
      final prevCompleted = completedCount;
      final prevFailed = failedCount;
      _tasks = tasks;
      notifyListeners();
      for (final t in tasks) {
        if (t.state == DownloadState.completed && !_notifiedCompleted.contains(t.id)) {
          _notifiedCompleted.add(t.id);
          NotificationService.instance.showDownloadComplete(t.title);
        }
        if (t.state == DownloadState.failed && !_notifiedFailed.contains(t.id)) {
          _notifiedFailed.add(t.id);
          NotificationService.instance.showDownloadFailed(t.title);
        }
      }
    });
    _tasks = _manager.tasks;
  }

  DownloadState? getStatusForSong(String title, String artist) {
    final match = _tasks.where((t) =>
        t.title.toLowerCase() == title.toLowerCase() &&
        t.artist.toLowerCase() == artist.toLowerCase());
    if (match.isEmpty) return null;
    return match.first.state;
  }

  double? getProgressForSong(String title, String artist) {
    final match = _tasks.where((t) =>
        t.title.toLowerCase() == title.toLowerCase() &&
        t.artist.toLowerCase() == artist.toLowerCase());
    if (match.isEmpty) return null;
    return match.first.progress;
  }

  String? getErrorForSong(String title, String artist) {
    final match = _tasks.where((t) =>
        t.title.toLowerCase() == title.toLowerCase() &&
        t.artist.toLowerCase() == artist.toLowerCase());
    if (match.isEmpty) return null;
    return match.first.error;
  }

  void enqueueTrack({
    required String spotifyTrackId,
    required String title,
    required String artist,
    String? album,
    String? imageUrl,
  }) {
    _manager.addTask(
      spotifyTrackId: spotifyTrackId,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
    );
  }

  void enqueuePlaylist(List<Map<String, String>> tracks) {
    _manager.addTasks(tracks);
  }

  void cancelTask(String taskId) => _manager.cancelTask(taskId);
  void cancelAll() => _manager.cancelAll();
  void retryTask(String taskId) => _manager.retryTask(taskId);
  void retryAllFailed() => _manager.retryAllFailed();
  void clearCompleted() {
    _manager.clearCompleted();
    _notifiedCompleted.clear();
  }

  void clearFailed() {
    _manager.clearFailed();
    _notifiedFailed.clear();
  }

  String stateText(DownloadTask task) {
    if (task.cancelled) return 'Cancelled';
    switch (task.state) {
      case DownloadState.pending:
        return 'Pending';
      case DownloadState.downloading:
        if (task.progress < 0.25) return 'Resolving source...';
        if (task.progress < 0.75) return 'Downloading...';
        if (task.progress < 0.90) return 'Embedding metadata...';
        if (task.progress < 1.0) return 'Processing...';
        return 'Downloading...';
      case DownloadState.completed:
        return 'Completed';
      case DownloadState.failed:
        return task.error ?? 'Failed';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
