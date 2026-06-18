import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

enum SyncState { idle, syncing, completed, error }

class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  Timer? _syncTimer;
  SyncState _state = SyncState.idle;
  String? _lastError;

  SyncState get state => _state;
  String? get lastError => _lastError;

  void Function(SyncState state)? onStateChanged;

  Future<void> scheduleDailySync({
    required int hour,
    required int minute,
    bool wifiOnly = true,
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  }) async {
    await _db.setSetting('sync_hour', hour.toString());
    await _db.setSetting('sync_minute', minute.toString());
    await _db.setSetting('sync_wifi_only', wifiOnly.toString());
    await _db.setSetting('sync_days', days.join(','));
    await _db.setSetting('sync_enabled', 'true');

    _cancelTimer();
    _scheduleNext(hour, minute, days);
  }

  Future<Map<String, dynamic>> loadPreferences() async {
    final hour = await _db.getSetting('sync_hour');
    final minute = await _db.getSetting('sync_minute');
    final wifiOnly = await _db.getSetting('sync_wifi_only');
    final days = await _db.getSetting('sync_days');
    final enabled = await _db.getSetting('sync_enabled');

    if (enabled == 'true' && hour != null && minute != null) {
      final daysList = days?.split(',').map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList() ?? [1,2,3,4,5,6,7];
      _scheduleNext(int.parse(hour), int.parse(minute), daysList);
    }

    return {
      'hour': hour != null ? int.parse(hour) : 3,
      'minute': minute != null ? int.parse(minute) : 0,
      'wifiOnly': wifiOnly == 'true',
      'days': days?.split(',').map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList() ?? [1,2,3,4,5,6,7],
      'enabled': enabled == 'true',
    };
  }

  Future<void> triggerManualSync() async {
    _setState(SyncState.syncing);
    try {
      final connected = await _checkConnectivity();
      if (!connected) {
        _lastError = 'No network connection';
        _setState(SyncState.error);
        return;
      }
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final uri = Uri.parse('https://api.github.com/repos/safakmert0/melodi/contents/lib');
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent', 'Melodi/1.0');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          debugPrint('Sync: connectivity OK, body length=${body.length}');
        }
      } finally {
        client.close();
      }
      _setState(SyncState.completed);
    } catch (e) {
      _lastError = e.toString();
      _setState(SyncState.error);
    }
  }

  Future<void> cancelSync() async {
    _cancelTimer();
    await _db.setSetting('sync_enabled', 'false');
    _setState(SyncState.idle);
  }

  void _scheduleNext(int hour, int minute, List<int> days) {
    if (days.isEmpty) return;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    var hops = 0;
    while (!days.contains(next.weekday) && hops < 14) {
      next = next.add(const Duration(days: 1));
      hops++;
    }
    final delay = next.difference(now);
    if (delay.isNegative) return;
    _syncTimer = Timer(delay, () {
      triggerManualSync();
    });
    debugPrint('Sync scheduled: $next (in ${delay.inHours}h ${delay.inMinutes % 60}m)');
  }

  void _cancelTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<bool> _checkConnectivity() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(Uri.parse('https://clients3.google.com/generate_204'));
        final response = await request.close();
        return response.statusCode == 204;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  void _setState(SyncState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  void dispose() {
    _cancelTimer();
  }
}
