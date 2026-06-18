import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  bool _streamingEnabled = true;
  bool _streamOnCellular = false;

  bool get streamingEnabled => _streamingEnabled;
  bool get streamOnCellular => _streamOnCellular;

  Future<void> load() async {
    final streaming = await _db.getSetting('streaming_enabled');
    final cellular = await _db.getSetting('stream_on_cellular');
    _streamingEnabled = streaming != 'false';
    _streamOnCellular = cellular == 'true';
    notifyListeners();
  }

  Future<void> setStreamingEnabled(bool value) async {
    _streamingEnabled = value;
    await _db.setSetting('streaming_enabled', value.toString());
    notifyListeners();
  }

  Future<void> setStreamOnCellular(bool value) async {
    _streamOnCellular = value;
    await _db.setSetting('stream_on_cellular', value.toString());
    notifyListeners();
  }

  bool canStream(bool isOnCellular) {
    if (!_streamingEnabled) return false;
    if (isOnCellular && !_streamOnCellular) return false;
    return true;
  }
}
