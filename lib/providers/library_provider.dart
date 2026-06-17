import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../models/song_model.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/genre_model.dart';
import '../services/database_service.dart';
import '../services/music_scanner_service.dart';

enum SongSortField { title, artist, album, duration, dateAdded }

class LibraryProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final MusicScannerService _scanner = MusicScannerService();

  List<SongModel> _songs = [];
  List<AlbumModel> _albums = [];
  List<ArtistModel> _artists = [];
  List<GenreModel> _genres = [];
  List<SongModel> _favorites = [];
  List<SongModel> _recent = [];
  List<SongModel> _mostPlayed = [];

  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
  double _scanProgress = 0;
  SongSortField _sortField = SongSortField.title;
  bool _sortAscending = true;

  SongSortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  void setSortField(SongSortField field) {
    _sortField = field;
    _songs = _applySort(_songs);
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    _songs = _applySort(_songs);
    notifyListeners();
  }

  List<SongModel> _applySort(List<SongModel> songs) {
    final sorted = List<SongModel>.from(songs);
    switch (_sortField) {
      case SongSortField.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SongSortField.artist:
        sorted.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case SongSortField.album:
        sorted.sort((a, b) => a.album.compareTo(b.album));
        break;
      case SongSortField.duration:
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SongSortField.dateAdded:
        sorted.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
    }
    if (!_sortAscending) {
      sorted.sort((a, b) {
        switch (_sortField) {
          case SongSortField.title:
            return b.title.compareTo(a.title);
          case SongSortField.artist:
            return b.artist.compareTo(a.artist);
          case SongSortField.album:
            return b.album.compareTo(a.album);
          case SongSortField.duration:
            return b.duration.compareTo(a.duration);
          case SongSortField.dateAdded:
            return b.dateAdded.compareTo(a.dateAdded);
        }
      });
    }
    return sorted;
  }

  List<SongModel> get songs => List.unmodifiable(_songs);
  List<AlbumModel> get albums => List.unmodifiable(_albums);
  List<ArtistModel> get artists => List.unmodifiable(_artists);
  List<GenreModel> get genres => List.unmodifiable(_genres);
  List<SongModel> get favorites => List.unmodifiable(_favorites);
  List<SongModel> get recent => List.unmodifiable(_recent);
  List<SongModel> get mostPlayed => List.unmodifiable(_mostPlayed);
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String? get error => _error;
  double get scanProgress => _scanProgress;
  int get songCount => _songs.length;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final watchedFolder = await _db.getSetting('watched_folder');
      if (watchedFolder != null && watchedFolder.isNotEmpty) {
        await _scanner.scanDirectoryAndSync(watchedFolder);
      }

      _songs = _applySort(await _db.getAllSongs());
      _favorites = await _db.getFavoriteSongs();
      _recent = await _db.getRecentSongs();
      _mostPlayed = await _db.getMostPlayedSongs();
      _buildAlbums();
      _buildArtists();
      _buildGenres();
    } catch (e) {
      _error = 'Failed to load library: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> getWatchedFolder() => _db.getSetting('watched_folder');

  Future<void> setWatchedFolder(String? path) async {
    if (path != null && path.isNotEmpty) {
      await _db.setSetting('watched_folder', path);
      final newSongs = await _scanner.importFromDirectoryPath(path);
      if (newSongs.isNotEmpty) {
        _songs.addAll(newSongs);
      }
      _songs = _applySort(_songs);
      _buildAlbums();
      _buildArtists();
      _buildGenres();
      notifyListeners();
    } else {
      await _db.setSetting('watched_folder', '');
    }
  }

  Future<void> clearWatchedFolder() async {
    await _db.setSetting('watched_folder', '');
    notifyListeners();
  }

  void _buildAlbums() {
    final albumMap = <String, List<SongModel>>{};
    for (final song in _songs) {
      final key = '${song.album}|${song.artist}';
      albumMap.putIfAbsent(key, () => []).add(song);
    }

    _albums = albumMap.entries.map((entry) {
      final songs = entry.value;
      final first = songs.first;
      final totalDur = songs.fold<Duration>(
          Duration.zero, (sum, s) => sum + s.duration);
      return AlbumModel(
        id: entry.key,
        name: first.album,
        artist: first.artist,
        artwork: first.albumArt,
        songCount: songs.length,
        totalDuration: totalDur,
        year: first.year ?? 0,
        songIds: songs.map((s) => s.id).toList(),
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _buildArtists() {
    final artistMap = <String, List<SongModel>>{};
    for (final song in _songs) {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }

    _artists = artistMap.entries.map((entry) {
      final songs = entry.value;
      final albumNames = songs.map((s) => s.album).toSet();
      return ArtistModel(
        id: entry.key,
        name: entry.key,
        albumCount: albumNames.length,
        songCount: songs.length,
        albumIds: [],
        songIds: songs.map((s) => s.id).toList(),
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _buildGenres() {
    final genreMap = <String, List<SongModel>>{};
    for (final song in _songs) {
      final genre = song.genre ?? 'Unknown';
      genreMap.putIfAbsent(genre, () => []).add(song);
    }

    _genres = genreMap.entries.map((entry) {
      return GenreModel(
        id: entry.key,
        name: entry.key,
        songCount: entry.value.length,
        songIds: entry.value.map((s) => s.id).toList(),
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> scanMusic() async {
    _isScanning = true;
    _scanProgress = 0;
    _error = null;
    notifyListeners();

    try {
      final songs = await _scanner.scanAllSources();
      _songs = _applySort(songs);
      _buildAlbums();
      _buildArtists();
      _buildGenres();
      _favorites = await _db.getFavoriteSongs();
      _recent = await _db.getRecentSongs();
      _mostPlayed = await _db.getMostPlayedSongs();
      _scanProgress = 1.0;
    } catch (e) {
      _error = 'Scan failed: $e';
    }

    _isScanning = false;
    notifyListeners();
  }

  Future<void> importFromFiles() async {
    _isScanning = true;
    _error = null;
    notifyListeners();

    try {
      final songs = await _scanner.importFromFilePicker();
      if (songs.isNotEmpty) {
        _songs.addAll(songs);
        _buildAlbums();
        _buildArtists();
        _buildGenres();
      }
    } catch (e) {
      _error = 'Import failed: $e';
    }

    _isScanning = false;
    notifyListeners();
  }

  Future<void> importFromDirectory() async {
    _isScanning = true;
    _error = null;
    notifyListeners();

    try {
      final songs = await _scanner.importFromDirectory();
      if (songs.isNotEmpty) {
        _songs.addAll(songs);
        _buildAlbums();
        _buildArtists();
        _buildGenres();
      }
    } catch (e) {
      _error = 'Import failed: $e';
    }

    _isScanning = false;
    notifyListeners();
  }

  Future<void> importFromFilePaths(List<String> paths) async {
    _isScanning = true;
    _error = null;
    notifyListeners();

    try {
      final songs = await _scanner.importFromPaths(paths);
      if (songs.isNotEmpty) {
        _songs.addAll(songs);
        _buildAlbums();
        _buildArtists();
        _buildGenres();
      }
    } catch (e) {
      _error = 'Import failed: $e';
    }

    _isScanning = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(SongModel song) async {
    final newFav = !song.isFavorite;
    await _db.updateFavoriteStatus(song.id, newFav);
    final index = _songs.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _songs[index] = _songs[index].copyWith(isFavorite: newFav);
    }
    if (newFav) {
      _favorites.add(_songs[index]);
    } else {
      _favorites.removeWhere((s) => s.id == song.id);
    }
    notifyListeners();
  }

  Future<void> updateSong(SongModel song) async {
    final index = _songs.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _songs[index] = song;
      await _db.insertSong(song);
    }
    notifyListeners();
  }

  List<SongModel> getSongsForAlbum(AlbumModel album) {
    return _songs.where((s) => s.album == album.name).toList();
  }

  List<SongModel> getSongsForArtist(ArtistModel artist) {
    return _songs.where((s) => s.artist == artist.name).toList();
  }

  List<SongModel> getSongsForGenre(GenreModel genre) {
    return _songs.where((s) => s.genre == genre.name).toList();
  }

  List<SongModel> search(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    return _songs.where((s) {
      return s.title.toLowerCase().contains(lower) ||
          s.artist.toLowerCase().contains(lower) ||
          s.album.toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> refresh() async {
    await loadAll();
  }

  Future<void> clearLibrary() async {
    await _db.clearAllData();
    _songs.clear();
    _albums.clear();
    _artists.clear();
    _genres.clear();
    _favorites.clear();
    _recent.clear();
    _mostPlayed.clear();
    notifyListeners();
  }
}
