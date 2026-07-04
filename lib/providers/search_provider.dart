import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/youtube_service.dart';

class SearchProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final YouTubeService _youtubeService = YouTubeService();

  List<SongModel> _results = [];
  List<YouTubeVideo> _onlineResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _isSearchingOnline = false;
  String _query = '';
  Timer? _debounce;

  List<SongModel> get results => _results;
  List<YouTubeVideo> get onlineResults => _onlineResults;
  List<String> get recentSearches => _recentSearches;
  bool get isSearching => _isSearching;
  bool get isSearchingOnline => _isSearchingOnline;
  String get query => _query;

  void search(String query) {
    _query = query;
    _debounce?.cancel();

    if (query.isEmpty) {
      _results = [];
      _onlineResults = [];
      _isSearching = false;
      _isSearchingOnline = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _isSearchingOnline = true;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        _results = await _db.searchSongs(query);
      } catch (_) {
        _results = [];
      }
      _isSearching = false;
      notifyListeners();

      // Search online after local results
      try {
        _onlineResults = await _youtubeService.search(query);
      } catch (_) {
        _onlineResults = [];
      }
      _isSearchingOnline = false;
      notifyListeners();
    });
  }

  void addRecentSearch(String query) {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 20) {
      _recentSearches = _recentSearches.sublist(0, 20);
    }
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  void clearResults() {
    _results = [];
    _onlineResults = [];
    _query = '';
    _debounce?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
