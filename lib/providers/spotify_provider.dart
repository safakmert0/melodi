import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/spotify_service.dart';
import '../services/track_matcher.dart';
import '../models/song_model.dart';

class SpotifyProvider extends ChangeNotifier {
  final SpotifyService _service = SpotifyService();
  bool _isConnecting = false;
  String? _spDc;
  String? _username;
  List<SpotifyPlaylistItem> _playlists = [];
  List<SpotifyTrackItem> _likedSongs = [];
  bool _isImportingPlaylists = false;
  bool _isImportingLikedSongs = false;
  String? _error;
  final Map<String, String> _matchedTrackIds = {};

  SpotifyService get service => _service;
  bool get isConnected => _service.isConnected;
  bool get isConnecting => _isConnecting;
  String? get username => _username;
  List<SpotifyPlaylistItem> get playlists => _playlists;
  List<SpotifyTrackItem> get likedSongs => _likedSongs;
  bool get isImportingPlaylists => _isImportingPlaylists;
  bool get isImportingLikedSongs => _isImportingLikedSongs;
  String? get error => _error;
  Map<String, String> get matchedTrackIds => Map.unmodifiable(_matchedTrackIds);

  Future<void> init() async {
    final db = DatabaseService.instance;
    final spDc = await db.getSetting('spotify_sp_dc');
    if (spDc != null && spDc.isNotEmpty) {
      _spDc = spDc;
      final session = await _service.getAccessToken(spDc);
      if (session != null) {
        _username = session.username;
        notifyListeners();
      } else {
        _spDc = null;
        await db.setSetting('spotify_sp_dc', '');
      }
    }
    await _loadMatches();
  }

  Future<bool> connectWithCookie(String spDc) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _service.getAccessToken(spDc);
      if (session == null) {
        _error = 'Invalid or expired sp_dc cookie';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      _spDc = spDc;
      _username = session.username;

      final db = DatabaseService.instance;
      await db.setSetting('spotify_sp_dc', spDc);

      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveMatches() async {
    final db = DatabaseService.instance;
    await db.setSetting('spotify_matches', _matchedTrackIds.entries
        .map((e) => '${e.key}=${e.value}')
        .join(','));
  }

  Future<void> _loadMatches() async {
    final db = DatabaseService.instance;
    final raw = await db.getSetting('spotify_matches');
    if (raw != null && raw.isNotEmpty) {
      for (final entry in raw.split(',')) {
        final parts = entry.split('=');
        if (parts.length == 2) {
          _matchedTrackIds[parts[0]] = parts[1];
        }
      }
    }
  }

  Future<void> disconnect() async {
    _spDc = null;
    _username = null;
    _playlists = [];
    _likedSongs = [];
    _error = null;

    final db = DatabaseService.instance;
    await db.setSetting('spotify_sp_dc', '');
    await db.setSetting('spotify_matches', '');

    notifyListeners();
  }

  Map<String, String> matchTracks(List<SpotifyTrackItem> spotifyTracks, List<SongModel> localSongs) {
    final matches = <String, String>{};
    for (final st in spotifyTracks) {
      double bestScore = 0.5;
      String? bestMatch;
      for (final ls in localSongs) {
        final score = TrackMatcher.scoreWithDuration(
          st.name, st.artists.join(' '), st.durationMs,
          ls.title, ls.artist, ls.duration.inMilliseconds,
        );
        if (score > bestScore) {
          bestScore = score;
          bestMatch = ls.id;
        }
      }
      if (bestMatch != null) {
        matches[st.id] = bestMatch;
      }
    }
    _matchedTrackIds.addAll(matches);
    await _saveMatches();
    notifyListeners();
    return matches;
  }

  Future<bool> likeTrack(String trackId) async {
    return _service.likeSpotifyTrack(trackId);
  }

  Future<bool> unlikeTrack(String trackId) async {
    return _service.unlikeSpotifyTrack(trackId);
  }

  Future<List<SpotifyPlaylistItem>> importPlaylists() async {
    _isImportingPlaylists = true;
    _error = null;
    notifyListeners();

    try {
      if (_service.isExpiringSoon) {
        await _service.refreshAccessToken();
      }

      _playlists = await _service.getUserPlaylists();
      notifyListeners();
      return _playlists;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    } finally {
      _isImportingPlaylists = false;
      notifyListeners();
    }
  }

  Future<List<SpotifyTrackItem>> importLikedSongs() async {
    _isImportingLikedSongs = true;
    _error = null;
    notifyListeners();

    try {
      if (_service.isExpiringSoon) {
        await _service.refreshAccessToken();
      }

      _likedSongs = await _service.getLikedSongs();
      notifyListeners();
      return _likedSongs;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    } finally {
      _isImportingLikedSongs = false;
      notifyListeners();
    }
  }
}
