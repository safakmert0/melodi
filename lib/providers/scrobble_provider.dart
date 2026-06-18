import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/scrobble_service.dart';
import '../services/ytmusic_service.dart';
import '../services/spotify_service.dart';

class ScrobbleProvider extends ChangeNotifier {
  final ScrobbleService _service;
  bool _enabled = false;
  bool _isScrobbling = false;
  DateTime? _lastScrobbledAt;
  int _scrobbleCount = 0;
  String? _error;
  List<ScrobbleItem> _recentHistory = [];
  Timer? _autoTimer;

  ScrobbleProvider({required ScrobbleService service}) : _service = service;

  ScrobbleService get service => _service;
  bool get enabled => _enabled;
  bool get isScrobbling => _isScrobbling || _service.isProcessing;
  DateTime? get lastScrobbledAt => _lastScrobbledAt;
  int get scrobbleCount => _scrobbleCount;
  String? get error => _error;
  List<ScrobbleItem> get recentHistory => _recentHistory;

  Future<void> init() async {
    final db = DatabaseService.instance;
    final enabled = await db.getSetting('scrobble_enabled');
    if (enabled == 'true') {
      _enabled = true;
      _startAuto();
    }
    final count = await db.getScrobbleCount();
    _scrobbleCount = count;
    await _loadRecentHistory();
    notifyListeners();
  }

  Future<void> enable() async {
    _enabled = true;
    final db = DatabaseService.instance;
    await db.setSetting('scrobble_enabled', 'true');
    _startAuto();
    notifyListeners();
  }

  Future<void> disable() async {
    _enabled = false;
    _stopAuto();
    final db = DatabaseService.instance;
    await db.setSetting('scrobble_enabled', 'false');
    notifyListeners();
  }

  Future<int> scrobbleNow() async {
    if (_isScrobbling) return 0;
    _isScrobbling = true;
    _error = null;
    notifyListeners();

    try {
      final count = await _service.processRecentHistory();
      if (count > 0) {
        _lastScrobbledAt = DateTime.now();
        _scrobbleCount += count;
        final db = DatabaseService.instance;
        await _loadRecentHistory();
      }
      return count;
    } catch (e) {
      _error = e.toString();
      debugPrint('scrobbleNow error: $e');
      return 0;
    } finally {
      _isScrobbling = false;
      notifyListeners();
    }
  }

  void _startAuto() {
    _stopAuto();
    _autoTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      scrobbleNow();
    });
    _service.startAutoScrobble(15);
  }

  void _stopAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _service.stopAutoScrobble();
  }

  Future<void> _loadRecentHistory() async {
    final db = DatabaseService.instance;
    final rows = await db.getRecentScrobbles(10);
    _recentHistory = rows.map((row) {
      return ScrobbleItem.fromDb(row);
    }).toList();
  }

  @override
  void dispose() {
    _stopAuto();
    _service.dispose();
    super.dispose();
  }
}
