import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';
import '../services/spotify_service.dart';
import '../services/ytmusic_service.dart';

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

  void setServices({
    SpotifyService? spotify,
    YTMusicService? ytmusic,
  }) {
    _service.setServices(spotify: spotify, ytmusic: ytmusic);
  }

  Future<void> init() async {
    await loadPreferences();
    final spotifyConnected = _service.isSpotifyConnected;
    final ytConnected = _service.isYTMusicConnected;
    if ((spotifyConnected || ytConnected) && _service.state != SyncState.syncing) {
      await triggerSync();
    }
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
