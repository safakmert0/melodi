import 'dart:async';
import 'package:flutter/material.dart';
import 'database_service.dart';
import 'sync_service.dart';

class SyncScheduler {
  static final SyncScheduler _instance = SyncScheduler._();
  factory SyncScheduler() => _instance;
  SyncScheduler._();

  final DatabaseService _db = DatabaseService.instance;
  Timer? _timer;

  Future<void> scheduleSync({
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    TimeOfDay time = const TimeOfDay(hour: 3, minute: 0),
  }) async {
    await _db.setSetting('sync_schedule_days', daysOfWeek.join(','));
    await _db.setSetting(
        'sync_schedule_time', '${time.hour}:${time.minute.toString().padLeft(2, '0')}');
    await _db.setSetting('sync_schedule_enabled', 'true');
    _scheduleNext(daysOfWeek, time);
  }

  Future<void> cancelScheduledSync() async {
    _timer?.cancel();
    _timer = null;
    await _db.setSetting('sync_schedule_enabled', 'false');
  }

  Future<void> runSyncNow() async {
    final service = SyncService();
    await service.triggerManualSync();
    _rescheduleIfNeeded();
  }

  Future<DateTime?> getNextSyncTime() async {
    final daysStr = await _db.getSetting('sync_schedule_days');
    final timeStr = await _db.getSetting('sync_schedule_time');
    final enabled = await _db.getSetting('sync_schedule_enabled');
    if (enabled != 'true' || daysStr == null || timeStr == null) return null;
    final days = daysStr
        .split(',')
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e > 0)
        .toList();
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]) ?? 3;
    final minute = int.tryParse(parts[1]) ?? 0;
    return _calculateNext(days, TimeOfDay(hour: hour, minute: minute));
  }

  Future<Map<String, dynamic>> getSyncSchedule() async {
    final daysStr = await _db.getSetting('sync_schedule_days');
    final timeStr = await _db.getSetting('sync_schedule_time');
    final enabled = await _db.getSetting('sync_schedule_enabled');
    final next = await getNextSyncTime();
    return {
      'enabled': enabled == 'true',
      'days': daysStr
              ?.split(',')
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7],
      'time': timeStr ?? '03:00',
      'nextSync': next,
    };
  }

  Future<bool> isSyncScheduled() async {
    final enabled = await _db.getSetting('sync_schedule_enabled');
    return enabled == 'true';
  }

  void _scheduleNext(List<int> days, TimeOfDay time) {
    _timer?.cancel();
    final next = _calculateNext(days, time);
    if (next == null) return;
    final delay = next.difference(DateTime.now());
    if (delay.isNegative) return;
    _timer = Timer(delay, () async {
      _timer = null;
      await runSyncNow();
      _rescheduleIfNeeded();
    });
  }

  Future<void> _rescheduleIfNeeded() async {
    final schedule = await getSyncSchedule();
    if (schedule['enabled'] == true) {
      final days = (schedule['days'] as List<int>);
      final timeStr = schedule['time'] as String;
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 3;
        final minute = int.tryParse(parts[1]) ?? 0;
        _scheduleNext(days, TimeOfDay(hour: hour, minute: minute));
      }
    }
  }

  DateTime? _calculateNext(List<int> days, TimeOfDay time) {
    if (days.isEmpty) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    var hops = 0;
    while (!days.contains(next.weekday) && hops < 14) {
      next = next.add(const Duration(days: 1));
      hops++;
    }
    return next;
  }

  void dispose() {
    _timer?.cancel();
  }
}
