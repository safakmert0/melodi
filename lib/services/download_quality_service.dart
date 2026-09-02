// Placeholder - DownloadQuality enum SongModel'de yok, stub for build
class DownloadQualityService {
  static final DownloadQualityService _instance = DownloadQualityService._internal();
  factory DownloadQualityService() => _instance;
  DownloadQualityService._internal();
  Future<void> setQuality(dynamic q) async {}
  Future<dynamic> getQuality() async => null;
  String getQualityDisplayName() => 'Yüksek';
}
