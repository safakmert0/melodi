import 'package:flutter/foundation.dart';
import '../core/localization.dart';
import '../services/sources/youtube_music_source.dart';
import '../services/music_source.dart';

class YouTubeProvider extends ChangeNotifier {
  final YouTubeMusicSource _source = YouTubeMusicSource();

  List<OnlineTrack> _results = [];
  bool _isSearching = false;
  String _query = '';
  bool _isDownloading = false;
  String? _downloadProgress;

  List<OnlineTrack> get results => _results;
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

    _results = await _source.search(query);
    _isSearching = false;
    notifyListeners();
  }

  void clearResults() {
    _results = [];
    _query = '';
    notifyListeners();
  }

  Future<String?> getStreamUrl(String videoId) async {
    return await _source.getStreamUrl(OnlineTrack(
      id: videoId,
      title: '',
      artist: '',
      duration: Duration.zero,
      source: MusicSourceType.youtube,
    ));
  }

  Future<String?> playAudio(String videoId, String title) async {
    _isDownloading = true;
    _downloadProgress = '${AppLocale.tr('loading_song')} $title';
    notifyListeners();

    final path = await DownloadManager().addTask(
      spotifyTrackId: 'youtube:$videoId',
      title: title,
      artist: '',
      sourceVideoId: videoId,
    ) ? 'started' : null;

    _isDownloading = false;
    _downloadProgress = path != null
        ? AppLocale.tr('loading_song')
        : AppLocale.tr('download_failed');
    notifyListeners();

    return path;
  }

  Future<String?> downloadAudio(String videoId, String title) async {
    _isDownloading = true;
    _downloadProgress = '${AppLocale.tr('downloading')} $title';
    notifyListeners();

    final path = await DownloadManager().addTask(
      spotifyTrackId: 'youtube:$videoId',
      title: title,
      artist: '',
      sourceVideoId: videoId,
    ) ? 'started' : null;

    _isDownloading = false;
    _downloadProgress = path != null
        ? AppLocale.tr('download_complete')
        : AppLocale.tr('download_failed');
    notifyListeners();

    return path;
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }
}