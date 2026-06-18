import 'database_service.dart';

class AudioQualityService {
  static final AudioQualityService _instance = AudioQualityService._();
  factory AudioQualityService() => _instance;
  AudioQualityService._();

  final DatabaseService _db = DatabaseService.instance;

  Future<String> getStreamingQuality() async {
    return (await _db.getSetting('streaming_quality')) ?? 'auto';
  }

  Future<void> setStreamingQuality(String quality) async {
    await _db.setSetting('streaming_quality', quality);
  }

  Future<String> getDownloadQuality() async {
    return (await _db.getSetting('download_quality')) ?? 'high';
  }

  Future<void> setDownloadQuality(String quality) async {
    await _db.setSetting('download_quality', quality);
  }

  Future<String> getCellularQuality() async {
    return (await _db.getSetting('cellular_quality')) ?? 'auto';
  }

  Future<void> setCellularQuality(String quality) async {
    await _db.setSetting('cellular_quality', quality);
  }

  Future<String> getWifiQuality() async {
    return (await _db.getSetting('wifi_quality')) ?? 'high';
  }

  Future<void> setWifiQuality(String quality) async {
    await _db.setSetting('wifi_quality', quality);
  }

  Future<Map<String, dynamic>> getStorageManagement() async {
    final keep = await _db.getSetting('keep_downloads_after_playing');
    final autoDelete = await _db.getSetting('auto_delete_days');
    return {
      'keepDownloads': keep != 'false',
      'autoDeleteDays': autoDelete != null ? int.tryParse(autoDelete) : null,
    };
  }

  Future<void> setStorageManagement({
    bool? keepDownloads,
    int? autoDeleteDays,
  }) async {
    if (keepDownloads != null) {
      await _db.setSetting('keep_downloads_after_playing', keepDownloads.toString());
    }
    if (autoDeleteDays != null) {
      await _db.setSetting('auto_delete_days', autoDeleteDays.toString());
    }
  }
}
