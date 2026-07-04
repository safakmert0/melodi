import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/multi_source_search.dart';
import '../services/music_source.dart';

class SearchProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final MultiSourceSearch _multiSource = MultiSourceSearch();

  List<SongModel> _results = [];
  List<OnlineTrack> _onlineResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _isSearchingOnline = false;
  String _query = '';
  Timer? _debounce;
  StreamSubscription<List<OnlineTrack>>? _onlineSub;

  List<SongModel> get results => _results;
  List<OnlineTrack> get onlineResults => _onlineResults;
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

      // Search online across all sources
      _onlineSub?.cancel();
      _onlineResults = [];
      _onlineSub = _multiSource.searchAll(query).listen(
        (tracks) {
          _onlineResults = tracks;
          _isSearchingOnline = false;
          notifyListeners();
        },
        onDone: () {
          _isSearchingOnline = false;
          notifyListeners();
        },
        onError: (_) {
          _onlineResults = [];
          _isSearchingOnline = false;
          notifyListeners();
        },
      );
    });
  }

  Future<String?> getStreamUrl(OnlineTrack track) async {
    return await _multiSource.getStreamUrl(track);
  }

  Future<String?> getStreamUrlWithFallback(OnlineTrack track) async {
    return await _multiSource.getStreamUrlWithFallback(track, query: _query);
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
    _onlineSub?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _onlineSub?.cancel();
    _multiSource.dispose();
    super.dispose();
  }
}
