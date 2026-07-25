import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/spotify_service.dart';
import '../services/ytmusic_service.dart';
import '../services/track_matcher.dart';

enum SyncState { idle, syncing, completed, error }

class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  Timer? _syncTimer;
  SyncState _state = SyncState.idle;
  String? _lastError;

  SpotifyService? _spotify;
  YTMusicService? _ytmusic;

  SyncState get state => _state;
  String? get lastError => _lastError;
  bool get isSpotifyConnected => _spotify?.isConnected ?? false;
  bool get isYTMusicConnected => _ytmusic?.isConnected ?? false;

  void Function(SyncState state)? onStateChanged;

  void setServices({
    SpotifyService? spotify,
    YTMusicService? ytmusic,
  }) {
    _spotify = spotify;
    _ytmusic = ytmusic;
  }

  Future<void> scheduleDailySync({
    required int hour,
    required int minute,
    bool wifiOnly = true,
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  }) async {
    await _db.setSetting('sync_hour', hour.toString());
    await _db.setSetting('sync_minute', minute.toString());
    await _db.setSetting('sync_wifi_only', wifiOnly.toString());
    await _db.setSetting('sync_days', days.join(','));
    await _db.setSetting('sync_enabled', 'true');

    _cancelTimer();
    _scheduleNext(hour, minute, days);
  }

  Future<Map<String, dynamic>> loadPreferences() async {
    final hour = await _db.getSetting('sync_hour');
    final minute = await _db.getSetting('sync_minute');
    final wifiOnly = await _db.getSetting('sync_wifi_only');
    final days = await _db.getSetting('sync_days');
    final enabled = await _db.getSetting('sync_enabled');

    if (enabled == 'true' && hour != null && minute != null) {
      final daysList = days
              ?.split(',')
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7];
      _scheduleNext(int.parse(hour), int.parse(minute), daysList);
    }

    return {
      'hour': hour != null ? int.parse(hour) : 3,
      'minute': minute != null ? int.parse(minute) : 0,
      'wifiOnly': wifiOnly == 'true',
      'days': days
              ?.split(',')
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7],
      'enabled': enabled == 'true',
    };
  }

  Future<void> triggerManualSync() async {
    _setState(SyncState.syncing);
    _lastError = null;
    try {
      final connected = await _checkConnectivity();
      if (!connected) {
        _lastError = 'No network connection';
        _setState(SyncState.error);
        return;
      }

      if (_spotify != null && _spotify!.isExpiringSoon) {
        await _spotify!.refreshAccessToken();
      }

      // Pull: Spotify playlists → local
      if (_spotify != null && _spotify!.isConnected) {
        await _pullSpotifyPlaylists();
        await _syncSpotifyLikedSongs();
      }

      // Pull: YT Music playlists → local
      if (_ytmusic != null && _ytmusic!.isConnected) {
        await _pullYTMusicPlaylists();
        await _syncYTMusicLikedSongs();
      }

      _setState(SyncState.completed);
    } catch (e) {
      _lastError = e.toString();
      _setState(SyncState.error);
    }
  }

  Future<void> _pullSpotifyPlaylists() async {
    final remotePlaylists = await _spotify!.getUserPlaylists();

    for (final rp in remotePlaylists) {
      final playlistName = 'Spotify — ${rp.name}';
      final existingPlaylists = await _db.getAllPlaylists();
      PlaylistModel? existing;
      for (final p in existingPlaylists) {
        if (p.name == playlistName) {
          existing = p;
          break;
        }
      }

      final tracks = await _spotify!.getPlaylistTracks(rp.id);
      final localSongs = await _db.getAllSongs();
      final matchedIds = <String>[];

      for (final track in tracks) {
        double bestScore = 0.3;
        String? bestId;
        for (final ls in localSongs) {
          final score = TrackMatcher.scoreWithDuration(
            track.name,
            track.artists.join(' '),
            track.durationMs,
            ls.title,
            ls.artist,
            ls.duration.inMilliseconds,
          );
          if (score > bestScore) {
            bestScore = score;
            bestId = ls.id;
          }
        }
        if (bestId != null) {
          matchedIds.add(bestId);
        } else {
          // Keep unmatched Spotify entries visible in the local playlist.
          // They can be resolved/downloaded later instead of disappearing.
          final placeholder = SongModel(
            id: 'spotify:${track.id}',
            title: track.name,
            artist: track.artists.join(', '),
            album: track.albumName ?? '',
            duration: Duration(milliseconds: track.durationMs),
            filePath: 'spotify://${track.id}',
            fileSize: 0,
          );
          await _db.insertSong(placeholder);
          localSongs.add(placeholder);
          matchedIds.add(placeholder.id);
        }
      }

      // Create or update playlist even if no tracks matched locally
      String localId;
      if (existing != null) {
        if (matchedIds.isNotEmpty) {
          final updated = existing.copyWith(songIds: matchedIds);
          await _db.insertPlaylist(updated);
        }
        localId = existing.id;
      } else {
        localId = Uuid().v4();
        final newPlaylist = PlaylistModel(
          id: localId,
          name: playlistName,
          description: 'Synced from Spotify',
          songIds: matchedIds,
        );
        await _db.insertPlaylist(newPlaylist);
      }
      await _db.setRemotePlaylistId(localId, rp.id, 'spotify');
    }
  }

  Future<void> _pullYTMusicPlaylists() async {
    final remotePlaylists = await _ytmusic!.getLibraryPlaylists();

    for (final rp in remotePlaylists) {
      final playlistName = 'YT Music — ${rp.title}';
      final existingPlaylists = await _db.getAllPlaylists();
      PlaylistModel? existing;
      for (final p in existingPlaylists) {
        if (p.name == playlistName) {
          existing = p;
          break;
        }
      }

      final tracks = await _ytmusic!.getPlaylistTracks(rp.playlistId);
      final localSongs = await _db.getAllSongs();
      final matchedIds = <String>[];

      for (final track in tracks) {
        double bestScore = 0.3;
        String? bestId;
        for (final ls in localSongs) {
          final score = TrackMatcher.scoreWithDuration(
            track.title,
            track.artists,
            track.durationMs ?? 0,
            ls.title,
            ls.artist,
            ls.duration.inMilliseconds,
          );
          if (score > bestScore) {
            bestScore = score;
            bestId = ls.id;
          }
        }
        if (bestId != null) matchedIds.add(bestId);
      }

      // Create or update playlist even if no tracks matched locally
      String localId;
      if (existing != null) {
        if (matchedIds.isNotEmpty) {
          final updated = existing.copyWith(songIds: matchedIds);
          await _db.insertPlaylist(updated);
        }
        localId = existing.id;
      } else {
        localId = Uuid().v4();
        final newPlaylist = PlaylistModel(
          id: localId,
          name: playlistName,
          description: 'Synced from YT Music',
          songIds: matchedIds,
        );
        await _db.insertPlaylist(newPlaylist);
      }
      await _db.setRemotePlaylistId(localId, rp.playlistId, 'ytmusic');
    }
  }

  Future<void> _syncSpotifyLikedSongs() async {
    try {
      final likedSongs = await _spotify!.getLikedSongs(limit: 50);
      if (likedSongs.isEmpty) return;

      final localSongs = await _db.getAllSongs();
      final matchedIds = <String>[];

      for (final track in likedSongs) {
        double bestScore = 0.3;
        String? bestId;
        for (final ls in localSongs) {
          final score = TrackMatcher.scoreWithDuration(
            track.name,
            track.artists.join(' '),
            track.durationMs,
            ls.title,
            ls.artist,
            ls.duration.inMilliseconds,
          );
          if (score > bestScore) {
            bestScore = score;
            bestId = ls.id;
          }
        }
        if (bestId != null) matchedIds.add(bestId);
      }

      if (matchedIds.isNotEmpty) {
        final playlistName = 'Spotify — Beğenilen Şarkılar';
        final existingPlaylists = await _db.getAllPlaylists();
        PlaylistModel? existing;
        for (final p in existingPlaylists) {
          if (p.name == playlistName) {
            existing = p;
            break;
          }
        }

        if (existing != null) {
          final updated = existing.copyWith(songIds: matchedIds);
          await _db.insertPlaylist(updated);
        } else {
          final newPlaylist = PlaylistModel(
            id: Uuid().v4(),
            name: playlistName,
            description: 'Liked songs from Spotify',
            songIds: matchedIds,
          );
          await _db.insertPlaylist(newPlaylist);
        }
      }
    } catch (e) {
      debugPrint('SyncService._syncSpotifyLikedSongs failed: $e');
    }
  }

  Future<void> _syncYTMusicLikedSongs() async {
    try {
      final likedSongs = await _ytmusic!.getLibrarySongs();
      if (likedSongs.isEmpty) return;

      final localSongs = await _db.getAllSongs();
      final matchedIds = <String>[];

      for (final track in likedSongs) {
        double bestScore = 0.3;
        String? bestId;
        for (final ls in localSongs) {
          final score = TrackMatcher.scoreWithDuration(
            track.title,
            track.artists,
            track.durationMs ?? 0,
            ls.title,
            ls.artist,
            ls.duration.inMilliseconds,
          );
          if (score > bestScore) {
            bestScore = score;
            bestId = ls.id;
          }
        }
        if (bestId != null) matchedIds.add(bestId);
      }

      if (matchedIds.isNotEmpty) {
        final playlistName = 'YT Music — Beğenilen Şarkılar';
        final existingPlaylists = await _db.getAllPlaylists();
        PlaylistModel? existing;
        for (final p in existingPlaylists) {
          if (p.name == playlistName) {
            existing = p;
            break;
          }
        }

        if (existing != null) {
          final updated = existing.copyWith(songIds: matchedIds);
          await _db.insertPlaylist(updated);
        } else {
          final newPlaylist = PlaylistModel(
            id: Uuid().v4(),
            name: playlistName,
            description: 'Liked songs from YT Music',
            songIds: matchedIds,
          );
          await _db.insertPlaylist(newPlaylist);
        }
      }
    } catch (e) {
      debugPrint('SyncService._syncYTMusicLikedSongs failed: $e');
    }
  }

  // Push: local playlist changes → remote services
  Future<void> pushPlaylistToSpotify({
    required String localPlaylistId,
    required List<String> addedTrackUris,
    required List<String> removedTrackUris,
  }) async {
    if (_spotify == null || !_spotify!.isConnected) return;

    final syncState = await _db.getPlaylistSyncState(localPlaylistId);
    if (syncState == null || syncState['syncEnabled'] != 1) return;

    final remotePlaylistId = syncState['remotePlaylistId'] as String?;
    if (remotePlaylistId == null || remotePlaylistId.isEmpty) return;

    final direction = syncState['syncDirection'] as String? ?? 'bidirectional';
    if (direction == 'yt_to_spotify') return;

    try {
      if (addedTrackUris.isNotEmpty) {
        await _spotify!.addTracksToPlaylist(remotePlaylistId, addedTrackUris);
      }
      if (removedTrackUris.isNotEmpty) {
        await _spotify!
            .removeTracksFromPlaylist(remotePlaylistId, removedTrackUris);
      }
    } catch (e) {
      debugPrint('pushPlaylistToSpotify failed: $e');
    }
  }

  Future<void> pushPlaylistToYTMusic({
    required String localPlaylistId,
    required List<String> addedVideoIds,
    required List<String> removedVideoIds,
  }) async {
    if (_ytmusic == null || !_ytmusic!.isConnected) return;

    final syncState = await _db.getPlaylistSyncState(localPlaylistId);
    if (syncState == null || syncState['syncEnabled'] != 1) return;

    final remotePlaylistId = syncState['remotePlaylistId'] as String?;
    if (remotePlaylistId == null || remotePlaylistId.isEmpty) return;

    final direction = syncState['syncDirection'] as String? ?? 'bidirectional';
    if (direction == 'spotify_to_yt') return;

    try {
      if (addedVideoIds.isNotEmpty) {
        await _ytmusic!.addToPlaylist(remotePlaylistId, addedVideoIds);
      }
      if (removedVideoIds.isNotEmpty) {
        await _ytmusic!.removeFromPlaylist(remotePlaylistId, removedVideoIds);
      }
    } catch (e) {
      debugPrint('pushPlaylistToYTMusic failed: $e');
    }
  }

  Future<void> cancelSync() async {
    _cancelTimer();
    await _db.setSetting('sync_enabled', 'false');
    _setState(SyncState.idle);
  }

  void _scheduleNext(int hour, int minute, List<int> days) {
    if (days.isEmpty) return;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    var hops = 0;
    while (!days.contains(next.weekday) && hops < 14) {
      next = next.add(const Duration(days: 1));
      hops++;
    }
    final delay = next.difference(now);
    if (delay.isNegative) return;
    _syncTimer = Timer(delay, () {
      triggerManualSync();
    });
    debugPrint(
        'Sync scheduled: $next (in ${delay.inHours}h ${delay.inMinutes % 60}m)');
  }

  void _cancelTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<bool> _checkConnectivity() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client
            .getUrl(Uri.parse('https://clients3.google.com/generate_204'));
        final response = await request.close();
        return response.statusCode == 204;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  void _setState(SyncState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  void dispose() {
    _cancelTimer();
  }
}
