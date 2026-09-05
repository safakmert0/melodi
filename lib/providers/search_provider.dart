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
  String? _error;
  Timer? _debounce;
  StreamSubscription<List<OnlineTrack>>? _onlineSub;
  int _searchGeneration = 0;

  List<SongModel> get results => _results;
  List<OnlineTrack> get onlineResults => _onlineResults;
  List<String> get recentSearches => _recentSearches;
  bool get isSearching => _isSearching;
  bool get isSearchingOnline => _isSearchingOnline;
  String get query => _query;
  String? get error => _error;

  void search(String query) {
    final generation = ++_searchGeneration;
    _query = query;
    _debounce?.cancel();

    if (query.isEmpty) {
      _results = [];
      _onlineResults = [];
      _isSearching = false;
      _isSearchingOnline = false;
      _error = null;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _isSearchingOnline = true;
    _error = null;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 160), () async {
      try {
        final localResults = await _db.searchSongs(query);
        if (generation != _searchGeneration) return;
        _results = localResults;
      } catch (e) {
        if (generation != _searchGeneration) return;
        _results = [];
        _error = 'Yerel arama kullanılamıyor: $e';
      }
      _isSearching = false;
      notifyListeners();

      // Search online across all sources
      _onlineSub?.cancel();
      _onlineResults = [];
      _onlineSub = _multiSource.searchAll(query).listen(
        (tracks) {
          if (generation != _searchGeneration) return;
          _onlineResults = tracks;
          _isSearchingOnline = false;
          notifyListeners();
          unawaited(_multiSource.prefetchStreamUrls(tracks));
        },
        onDone: () {
          if (generation != _searchGeneration) return;
          _isSearchingOnline = false;
          notifyListeners();
        },
        onError: (_) {
          if (generation != _searchGeneration) return;
          _onlineResults = [];
          _isSearchingOnline = false;
          _error ??= 'Çevrim içi arama kullanılamıyor';
          notifyListeners();
        },
      );
    });
  }

  Future<String?> getStreamUrl(OnlineTrack track) async {
    return await _multiSource.getStreamUrl(track);
  }

  Future<String?> getStreamUrlWithFallback(
    OnlineTrack track, {
    Set<String> excludedUrls = const {},
    bool forPlayback = false,
  }) async {
    return await _multiSource
        .getStreamUrlWithFallback(
          track,
          query: _query,
          excludedUrls: excludedUrls,
          preferStableYouTubeReference: forPlayback,
        )
        .timeout(const Duration(milliseconds: 4800));
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
    _error = null;
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
