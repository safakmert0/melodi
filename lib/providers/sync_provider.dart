import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _service = SyncService();

  SyncService get service => _service;

  SyncState get state => _service.state;
  String? get lastError => _service.lastError;

  SyncProvider() {
    _service.onStateChanged = (_) {
      if (hasListeners) notifyListeners();
    };
  }

  Future<void> init() async {
    await loadPreferences();
  }

  Future<void> loadPreferences() async {
    await _service.loadPreferences();
    notifyListeners();
  }

  Future<void> scheduleSync({
    required int hour,
    required int minute,
    bool wifiOnly = true,
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  }) async {
    await _service.scheduleDailySync(
      hour: hour,
      minute: minute,
      wifiOnly: wifiOnly,
      days: days,
    );
    notifyListeners();
  }

  Future<void> triggerSync() async {
    await _service.triggerManualSync();
    notifyListeners();
  }

  Future<void> cancelSync() async {
    await _service.cancelSync();
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
