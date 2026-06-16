import 'package:flutter/foundation.dart';
import '../core/localization.dart';
import '../services/youtube_service.dart';

class YouTubeProvider extends ChangeNotifier {
  final YouTubeService _service = YouTubeService();

  List<YouTubeVideo> _results = [];
  bool _isSearching = false;
  String _query = '';
  bool _isDownloading = false;
  String? _downloadProgress;

  List<YouTubeVideo> get results => _results;
  bool get isSearching => _isSearching;
  String get query => _query;
  bool get isDownloading => _isDownloading;
  String? get downloadProgress => _downloadProgress;

  Future<void> search(String query) async {
    if (query.isEmpty) {
      _results = [];
      _query = '';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _query = query;
    notifyListeners();

    _results = await _service.search(query);
    _isSearching = false;
    notifyListeners();
  }

  void clearResults() {
    _results = [];
    _query = '';
    notifyListeners();
  }

  Future<String?> getAudioUrl(String videoId) async {
    return await _service.getAudioUrl(videoId);
  }

  Future<String?> downloadAudio(String videoId, String title) async {
    _isDownloading = true;
    _downloadProgress = '${AppLocale.tr('downloading')} $title';
    notifyListeners();

    final path = await _service.downloadAudio(videoId, title);

    _isDownloading = false;
    _downloadProgress = path != null ? AppLocale.tr('download_complete') : AppLocale.tr('download_failed');
    notifyListeners();

    return path;
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
