import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../services/spotify_service.dart';
import '../services/track_matcher.dart';
import '../models/song_model.dart';

class SpotifyProvider extends ChangeNotifier {
  static const _spDcKey = 'spotify_sp_dc';
  static const _accessTokenKey = 'spotify_access_token';

  final SpotifyService _service = SpotifyService();
  bool _isConnecting = false;
  String? _spDc;
  String? _username;
  List<SpotifyPlaylistItem> _playlists = [];
  List<SpotifyTrackItem> _likedSongs = [];
  bool _isImportingPlaylists = false;
  bool _isImportingLikedSongs = false;
  bool _isInitialized = false;
  String? _error;
  final Map<String, String> _matchedTrackIds = {};
  final Map<String, List<SpotifyTrackItem>> _playlistTrackCache = {};

  SpotifyService get service => _service;
  bool get isConnected => _service.isConnected;
  bool get isConnecting => _isConnecting;
  String? get username => _username;
  List<SpotifyPlaylistItem> get playlists => _playlists;
  List<SpotifyTrackItem> get likedSongs => _likedSongs;
  bool get isImportingPlaylists => _isImportingPlaylists;
  bool get isImportingLikedSongs => _isImportingLikedSongs;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  Map<String, String> get matchedTrackIds => Map.unmodifiable(_matchedTrackIds);

  Future<void> init() async {
    try {
      final db = DatabaseService.instance;
      final spDc = await _readSecret(_spDcKey);
      if (spDc != null && spDc.isNotEmpty) {
        _spDc = spDc;

        // Try to restore saved session first (avoids network call on every launch)
        final savedToken = await _readSecret(_accessTokenKey);
        final savedExpiry = await db.getSetting('spotify_expires_at');
        final savedUsername = await db.getSetting('spotify_username');
        final savedClientId = await db.getSetting('spotify_client_id');

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiry = int.tryParse(savedExpiry ?? '0') ?? 0;

        if (savedToken != null && savedToken.isNotEmpty && now < expiry - 60) {
          // Saved token is still valid — use it directly
          _service.restoreSession(
            accessToken: savedToken,
            refreshToken: spDc,
            expiresAtEpoch: expiry,
            username: savedUsername,
            clientId: savedClientId,
          );
          _username = savedUsername;
          notifyListeners();
        } else {
          // Token expired or missing — refresh from server
          try {
            final session = await _service.getAccessToken(spDc);
            if (session != null) {
              _username = session.username;
              await _saveSession(session);
              notifyListeners();
            } else {
              debugPrint(
                  'Spotify: Token refresh failed, keeping sp_dc for retry');
              _username = savedUsername;
              notifyListeners();
            }
          } catch (e) {
            debugPrint('Spotify: Init error, keeping session for retry: $e');
            _username = savedUsername;
          }
        }
      }
      await _loadMatches();
      await _loadPlaylists();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
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

      await _writeSecret(_spDcKey, spDc);
      await _saveSession(session);

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

  Future<void> _saveSession(SpotifySession session) async {
    final db = DatabaseService.instance;
    await _writeSecret(_accessTokenKey, session.accessToken);
    await db.setSetting(
        'spotify_expires_at', session.expiresAtEpoch.toString());
    await db.setSetting('spotify_username', session.username);
    await db.setSetting('spotify_client_id', session.clientId);
  }

  Future<String?> _readSecret(String key) async {
    final secureStorage = SecureStorageService.instance;
    final secureValue = await secureStorage.read(key);
    if (secureValue != null && secureValue.isNotEmpty) return secureValue;

    // One-time migration from versions that stored credentials in SQLite.
    final db = DatabaseService.instance;
    final legacyValue = await db.getSetting(key);
    if (legacyValue == null || legacyValue.isEmpty) return null;
    await secureStorage.write(key, legacyValue);
    await db.deleteSetting(key);
    return legacyValue;
  }

  Future<void> _writeSecret(String key, String value) async {
    await SecureStorageService.instance.write(key, value);
    await DatabaseService.instance.deleteSetting(key);
  }

  Future<void> _saveMatches() async {
    final db = DatabaseService.instance;
    await db.setSetting('spotify_matches',
        _matchedTrackIds.entries.map((e) => '${e.key}=${e.value}').join(','));
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
    _service.disconnect();
    _spDc = null;
    _username = null;
    _playlists = [];
    _likedSongs = [];
    _playlistTrackCache.clear();
    _error = null;

    final db = DatabaseService.instance;
    await SecureStorageService.instance.delete(_spDcKey);
    await SecureStorageService.instance.delete(_accessTokenKey);
    await db.deleteSetting('spotify_sp_dc');
    await db.setSetting('spotify_matches', '');
    await db.deleteSetting('spotify_access_token');
    await db.setSetting('spotify_expires_at', '');
    await db.setSetting('spotify_username', '');
    await db.setSetting('spotify_client_id', '');

    notifyListeners();
  }

  Map<String, String> matchTracks(
      List<SpotifyTrackItem> spotifyTracks, List<SongModel> localSongs) {
    final matches = <String, String>{};
    for (final st in spotifyTracks) {
      double bestScore = 0.5;
      String? bestMatch;
      for (final ls in localSongs) {
        final score = TrackMatcher.scoreWithDuration(
          st.name,
          st.artists.join(' '),
          st.durationMs,
          ls.title,
          ls.artist,
          ls.duration.inMilliseconds,
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
    _saveMatches();
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
      // Try to refresh token if needed
      if (_service.isExpiringSoon && _spDc != null) {
        await _service.refreshAccessToken();
      }

      // If still not connected, try with saved sp_dc
      if (!_service.isConnected && _spDc != null) {
        final session = await _service.getAccessToken(_spDc!);
        if (session != null) {
          _username = session.username;
          await _saveSession(session);
        }
      }

      if (!_service.isConnected) {
        _error = 'Not connected. Please login again.';
        return [];
      }

      final refreshedPlaylists = await _service.getUserPlaylists();
      if (refreshedPlaylists.isEmpty && _playlists.isNotEmpty) {
        _error =
            'Spotify çalma listeleri yenilenemedi; kayıtlı liste korunuyor.';
        notifyListeners();
        return _playlists;
      }
      _playlists = refreshedPlaylists;
      final playlistIds = _playlists.map((playlist) => playlist.id).toSet();
      _playlistTrackCache
          .removeWhere((playlistId, _) => !playlistIds.contains(playlistId));
      await _savePlaylists();
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

  List<SpotifyTrackItem>? cachedPlaylistTracks(String playlistId) {
    final tracks = _playlistTrackCache[playlistId];
    return tracks == null ? null : List.unmodifiable(tracks);
  }

  Future<List<SpotifyTrackItem>> loadPlaylistTracks(
    SpotifyPlaylistItem playlist, {
    bool refresh = false,
  }) async {
    final cached = _playlistTrackCache[playlist.id];
    if (!refresh && cached != null) return List.unmodifiable(cached);

    _error = null;
    try {
      if (_service.isExpiringSoon && _spDc != null) {
        final refreshed = await _service.refreshAccessToken();
        if (refreshed != null) {
          _username = refreshed.username;
          await _saveSession(refreshed);
        }
      }

      final tracks = await _service.getPlaylistTracks(playlist.id);
      if (tracks.isNotEmpty || playlist.trackCount == 0) {
        _playlistTrackCache[playlist.id] = List.from(tracks);
        final index = _playlists.indexWhere((item) => item.id == playlist.id);
        if (index >= 0 && _playlists[index].trackCount != tracks.length) {
          _playlists[index] = _playlists[index].copyWith(
            trackCount: tracks.length,
          );
          await _savePlaylists();
        }
        notifyListeners();
      } else {
        _error = 'Spotify çalma listesi şarkıları alınamadı.';
        notifyListeners();
      }
      return List.unmodifiable(tracks);
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final db = DatabaseService.instance;
      final encoded = jsonEncode(_playlists
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'ownerId': p.ownerId,
                'imageUrl': p.imageUrl,
                'trackCount': p.trackCount,
              })
          .toList());
      await db.setSetting('spotify_playlists', encoded);
    } catch (e) {
      debugPrint('Spotify _savePlaylists error: $e');
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final db = DatabaseService.instance;
      final saved = await db.getSetting('spotify_playlists');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        _playlists = decoded
            .map((e) => SpotifyPlaylistItem(
                  id: e['id'] as String,
                  name: e['name'] as String,
                  ownerId: e['ownerId'] as String? ?? '',
                  imageUrl: e['imageUrl'] as String?,
                  trackCount: e['trackCount'] as int? ?? 0,
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('Spotify _loadPlaylists error: $e');
    }
  }

  Future<List<SpotifyTrackItem>> importLikedSongs() async {
    _isImportingLikedSongs = true;
    _error = null;
    notifyListeners();

    try {
      // Try to refresh token if needed
      if (_service.isExpiringSoon && _spDc != null) {
        await _service.refreshAccessToken();
      }

      // If still not connected, try with saved sp_dc
      if (!_service.isConnected && _spDc != null) {
        final session = await _service.getAccessToken(_spDc!);
        if (session != null) {
          _username = session.username;
          await _saveSession(session);
        }
      }

      if (!_service.isConnected) {
        _error = 'Not connected. Please login again.';
        return [];
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
