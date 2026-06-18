import 'dart:convert';
import 'package:flutter/material.dart';
import 'database_service.dart';

class QueueItem {
  final String trackId;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final String source;
  final int durationMs;

  QueueItem({
    required this.trackId,
    required this.title,
    required this.artist,
    this.album = '',
    this.imageUrl = '',
    this.source = '',
    this.durationMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'album': album,
        'imageUrl': imageUrl,
        'source': source,
        'durationMs': durationMs,
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        trackId: json['trackId'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        source: json['source'] as String? ?? '',
        durationMs: json['durationMs'] as int? ?? 0,
      );
}

enum RepeatMode { off, all, one }

class QueueManager extends ChangeNotifier {
  List<QueueItem> _queue = [];
  List<QueueItem> _history = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleMode = false;
  bool _isLoading = false;

  List<QueueItem> get currentQueue => List.unmodifiable(_queue);
  List<QueueItem> get history => List.unmodifiable(_history);
  int get currentIndex => _currentIndex;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleMode => _shuffleMode;
  bool get isLoading => _isLoading;
  int get length => _queue.length;

  void addToQueue(QueueItem item) {
    _queue.add(item);
    notifyListeners();
    _autoSave();
  }

  void addToQueueNext(QueueItem item) {
    final insertIndex =
        _currentIndex >= 0 ? _currentIndex + 1 : _queue.length;
    _queue.insert(insertIndex, item);
    notifyListeners();
    _autoSave();
  }

  void addToQueueLater(List<QueueItem> items) {
    _queue.addAll(items);
    notifyListeners();
    _autoSave();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      notifyListeners();
      _autoSave();
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    notifyListeners();
    _autoSave();
  }

  void clearQueue() {
    _queue.clear();
    _history.clear();
    _currentIndex = -1;
    notifyListeners();
    _autoSave();
  }

  void shuffleQueue() {
    _queue.shuffle();
    notifyListeners();
    _autoSave();
  }

  QueueItem? getNextTrack() {
    if (_queue.isEmpty) return null;
    if (_shuffleMode) {
      _queue.shuffle();
    }
    _currentIndex++;
    if (_currentIndex >= _queue.length) {
      if (_repeatMode == RepeatMode.all) {
        _currentIndex = 0;
      } else if (_repeatMode == RepeatMode.one) {
        _currentIndex--;
      } else {
        _currentIndex = _queue.length;
        return null;
      }
    }
    final track = _queue[_currentIndex];
    _history.add(track);
    notifyListeners();
    _autoSave();
    return track;
  }

  QueueItem? getPreviousTrack() {
    if (_history.length < 2) return null;
    _history.removeLast();
    final track = _history.isNotEmpty ? _history.last : null;
    if (track != null) {
      _currentIndex = _queue.indexOf(track);
    }
    notifyListeners();
    _autoSave();
    return track;
  }

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> saveQueue() async {
    final db = DatabaseService.instance;
    final data = jsonEncode({
      'queue': _queue.map((e) => e.toJson()).toList(),
      'history': _history.map((e) => e.toJson()).toList(),
      'currentIndex': _currentIndex,
      'repeatMode': _repeatMode.index,
      'shuffleMode': _shuffleMode,
    });
    await db.setSetting('saved_queue', data);
  }

  Future<void> restoreQueue() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = DatabaseService.instance;
      final raw = await db.getSetting('saved_queue');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _queue = (data['queue'] as List)
            .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _history = (data['history'] as List)
            .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _currentIndex = data['currentIndex'] as int? ?? -1;
        _repeatMode =
            RepeatMode.values[data['repeatMode'] as int? ?? 0];
        _shuffleMode = data['shuffleMode'] as bool? ?? false;
      }
    } catch (_) {
      _queue = [];
      _history = [];
      _currentIndex = -1;
    }
    _isLoading = false;
    notifyListeners();
  }

  void _autoSave() {
    saveQueue();
  }
}
