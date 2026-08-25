import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/spotify_service.dart';
import '../services/track_matcher.dart';
import '../services/sources/youtube_music_source.dart';
import '../services/music_source.dart';

enum SyncState { idle, syncing, completed, error }

class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  Timer? _syncTimer;
  SyncState _state = SyncState.idle;
  String? _lastError;
  final Map<String, Future<Uint8List?>> _spotifyArtworkDownloads = {};

  SpotifyService? _spotify;
  YouTubeMusicSource? _ytmusicSource;

  SyncState get state => _state;
  String? get lastError => _lastError;
  bool get isSpotifyConnected => _spotify?.isConnected ?? false;
  bool get isYTMusicConnected => _ytmusicSource != null;

  void Function(SyncState state)? onStateChanged;

  void setServices({
    SpotifyService? spotify,
    YouTubeMusicSource? ytmusicSource,
  }) {
    _spotify = spotify;
    _ytmusicSource = ytmusicSource;
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

  Future<void> triggerManualSync({
    List<SpotifyPlaylistItem>? spotifyPlaylists,
  }) async {
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
        await _pullSpotifyPlaylists(remotePlaylists: spotifyPlaylists);
        await _syncSpotifyLikedSongs();
      }

      // Pull: YT Music playlists → local
      if (_ytmusicSource != null && _ytmusicSource!.isConnected) {
        await _pullYTMusicPlaylists();
        await _syncYTMusicLikedSongs();
      }

      _setState(SyncState.completed);
    } catch (e) {
      _lastError = e.toString();
      _setState(SyncState.error);
    }
  }

  Future<void> _pullSpotifyPlaylists({
    List<SpotifyPlaylistItem>? remotePlaylists,
  }) async {
    final remote = remotePlaylists ?? await _spotify!.getUserPlaylists();
    final existingPlaylists = await _db.getAllPlaylists();
    final syncStates = await _db.getAllSyncStates();
    final byRemoteId = <String, PlaylistModel>{};
    final byName = <String, List<PlaylistModel>>{};
    final claimedLocalIds = <String>{};
    final groupedByRemoteId = <String, List<PlaylistModel>>{};

    for (final playlist in existingPlaylists) {
      final state = syncStates[playlist.id];
      if (state?['remoteService'] != 'spotify') continue;
      final remoteId = state?['remotePlaylistId']?.toString();
      if (remoteId == null || remoteId.isEmpty) continue;
      groupedByRemoteId.putIfAbsent(remoteId, () => []).add(playlist);
    }

    final duplicateLocalIds = <String>{};
    for (final entry in groupedByRemoteId.entries) {
      final candidates = entry.value
        ..sort((left, right) {
          final songCount = right.songIds.length.compareTo(left.songIds.length);
          if (songCount != 0) return songCount;
          return right.updatedAt.compareTo(left.updatedAt);
        });
      byRemoteId[entry.key] = candidates.first;
      for (final duplicate in candidates.skip(1)) {
        duplicateLocalIds.add(duplicate.id);
        await _db.deletePlaylist(duplicate.id);
      }
    }

    final survivingPlaylists = existingPlaylists
        .where((playlist) => !duplicateLocalIds.contains(playlist.id))
        .toList();
    for (final playlist in survivingPlaylists) {
      byName.putIfAbsent(playlist.name, () => []).add(playlist);
      final state = syncStates[playlist.id];
      if (state?['remoteService'] == 'spotify') {
        final remoteId = state?['remotePlaylistId']?.toString();
        if (remoteId != null && remoteId.isNotEmpty) {
          byRemoteId.putIfAbsent(remoteId, () => playlist);
        }
      }
    }

    final localSongs = await _db.getAllSongs();
    final localById = {for (final song in localSongs) song.id: song};
    final cachedArtwork = await _db.getAllCachedAlbumArts();
    final artworkScheduled = <String>{};
    final artworkJobs = <Future<void>>[];

    // Remove only the empty, unprefixed shells created by the short-lived
    // legacy importer. User-created playlists and real Spotify mirrors stay.
    final remoteNames = remote.map((playlist) => playlist.name).toSet();
    for (final playlist in existingPlaylists) {
      if (playlist.description == 'Spotify' &&
          playlist.songIds.isEmpty &&
          remoteNames.contains(playlist.name)) {
        await _db.deletePlaylist(playlist.id);
      }
    }

    for (final remotePlaylist in remote) {
      try {
        final playlistName = 'Spotify — ${remotePlaylist.name}';
        PlaylistModel? existing = byRemoteId[remotePlaylist.id];

        if (existing == null) {
          final legacyCandidates = byName[playlistName] ?? const [];
          for (final candidate in legacyCandidates) {
            final state = syncStates[candidate.id];
            final mappedRemoteId = state?['remotePlaylistId']?.toString();
            if (!claimedLocalIds.contains(candidate.id) &&
                (mappedRemoteId == null ||
                    mappedRemoteId.isEmpty ||
                    mappedRemoteId == remotePlaylist.id)) {
              existing = candidate;
              break;
            }
          }
        }
        if (existing != null) {
          final staleMirrors =
              (byName[playlistName] ?? const []).where((candidate) {
            if (candidate.id == existing!.id) return false;
            final state = syncStates[candidate.id];
            final mappedRemoteId = state?['remotePlaylistId']?.toString();
            return mappedRemoteId == null ||
                mappedRemoteId.isEmpty ||
                mappedRemoteId == remotePlaylist.id;
          }).toList();
          for (final duplicate in staleMirrors) {
            await _db.deletePlaylist(duplicate.id);
            claimedLocalIds.add(duplicate.id);
          }
          byName[playlistName] = (byName[playlistName] ?? const [])
              .where((candidate) => !staleMirrors.contains(candidate))
              .toList();
          claimedLocalIds.add(existing.id);
        }

        List<SpotifyTrackItem> tracks = const [];
        try {
          tracks = await _spotify!.getPlaylistTracks(remotePlaylist.id);
        } catch (error) {
          debugPrint(
              'Spotify playlist tracks failed for ${remotePlaylist.id}: $error');
        }

        // A transient Spotify response must not make the whole playlist vanish.
        // Keep its last known songs (or create an empty visible shell) and retry
        // on the next sync.
        final matchedIds = tracks.isEmpty && remotePlaylist.trackCount > 0
            ? <String>[...?existing?.songIds]
            : <String>[];

        for (final track in tracks) {
          final placeholderId = 'spotify:${track.id}';
          final knownPlaceholder = localById[placeholderId];
          if (knownPlaceholder != null) {
            matchedIds.add(knownPlaceholder.id);
            if (track.albumImageUrl != null &&
                !cachedArtwork.containsKey(knownPlaceholder.id) &&
                artworkScheduled.add(knownPlaceholder.id)) {
              artworkJobs.add(
                _cacheSpotifyArtwork(knownPlaceholder.id, track.albumImageUrl!),
              );
              if (artworkJobs.length >= 6) {
                await Future.wait(artworkJobs);
                artworkJobs.clear();
              }
            }
            continue;
          }

          double bestScore = 0.65;
          String? bestId;
          for (final local in localSongs) {
            final score = TrackMatcher.scoreWithDuration(
              track.name,
              track.artists.join(' '),
              track.durationMs,
              local.title,
              local.artist,
              local.duration.inMilliseconds,
            );
            if (score > bestScore) {
              bestScore = score;
              bestId = local.id;
            }
          }
          if (bestId != null) {
            matchedIds.add(bestId);
            continue;
          }

          final placeholder = SongModel(
            id: placeholderId,
            title: track.name,
            artist: track.artists.join(', '),
            album: track.albumName ?? '',
            duration: Duration(milliseconds: track.durationMs),
            filePath: 'spotify://${track.id}',
            fileSize: 0,
          );
          await _db.insertSong(placeholder);
          localSongs.add(placeholder);
          localById[placeholder.id] = placeholder;
          matchedIds.add(placeholder.id);
          if (track.albumImageUrl != null) {
            artworkJobs.add(
              _cacheSpotifyArtwork(placeholder.id, track.albumImageUrl!),
            );
            if (artworkJobs.length >= 6) {
              await Future.wait(artworkJobs);
              artworkJobs.clear();
            }
          }
        }

        final PlaylistModel localPlaylist;
        if (existing != null) {
          localPlaylist = existing.copyWith(
            name: playlistName,
            description: 'Synced from Spotify',
            songIds: matchedIds,
          );
        } else {
          localPlaylist = PlaylistModel(
            id: const Uuid().v4(),
            name: playlistName,
            description: 'Synced from Spotify',
            songIds: matchedIds,
          );
        }
        await _db.insertPlaylist(localPlaylist);
        await _db.setRemotePlaylistId(
            localPlaylist.id, remotePlaylist.id, 'spotify');
        byRemoteId[remotePlaylist.id] = localPlaylist;
        byName.putIfAbsent(playlistName, () => []).add(localPlaylist);
        claimedLocalIds.add(localPlaylist.id);
      } catch (error, stackTrace) {
        debugPrint(
            'Spotify playlist sync failed for ${remotePlaylist.id}: $error\n$stackTrace');
      }
    }

    if (artworkJobs.isNotEmpty) await Future.wait(artworkJobs);
  }

  Future<void> _cacheSpotifyArtwork(String songId, String url) async {
    try {
      final bytes = await _spotifyArtworkDownloads.putIfAbsent(
        url,
        () async {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            return null;
          }
          if (response.bodyBytes.length > 5 * 1024 * 1024) return null;
          return response.bodyBytes;
        },
      );
      if (bytes != null) await _db.cacheAlbumArt(songId, bytes);
    } catch (error) {
      debugPrint('Spotify artwork cache failed: $error');
    }
  }

  Future<void> _pullYTMusicPlaylists() async {
    if (_ytmusicSource == null) return;
    
    final remotePlaylists = await _ytmusicSource!.search('playlist', limit: 50);
    final localSongs = await _db.getAllSongs();

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

      final tracks = await _ytmusicSource!.search('playlist:${rp.id}', limit: 100);
      final matchedIds = <String>[];

      for (final track in tracks) {
        double bestScore = 0.3;
        String? bestId;
        for (final ls in localSongs) {
          final score = TrackMatcher.scoreWithDuration(
            track.title,
            track.artist,
            track.duration.inMilliseconds,
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
      await _db.setRemotePlaylistId(localId, rp.id, 'ytmusic');
    }
  }

  Future<void> _syncSpotifyLikedSongs() async {
    try {
      final likedSongs = await _spotify!.getLikedSongs();
      if (likedSongs.isEmpty) return;

      final localSongs = await _db.getAllSongs();
      final localById = {for (final song in localSongs) song.id: song};
      final cachedArtwork = await _db.getAllCachedAlbumArts();
      final matchedIds = <String>[];
      final artworkJobs = <Future<void>>[];

      for (final track in likedSongs) {
        final placeholderId = 'spotify:${track.id}';
        if (localById.containsKey(placeholderId)) {
          matchedIds.add(placeholderId);
          if (track.albumImageUrl != null &&
              !cachedArtwork.containsKey(placeholderId)) {
            artworkJobs.add(
              _cacheSpotifyArtwork(placeholderId, track.albumImageUrl!),
            );
            if (artworkJobs.length >= 6) {
              await Future.wait(artworkJobs);
              artworkJobs.clear();
            }
          }
          continue;
        }
        double bestScore = 0.65;
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
          continue;
        }

        final placeholder = SongModel(
          id: placeholderId,
          title: track.name,
          artist: track.artists.join(', '),
          album: track.albumName ?? '',
          duration: Duration(milliseconds: track.durationMs),
          filePath: 'spotify://${track.id}',
          fileSize: 0,
        );
        await _db.insertSong(placeholder);
        localSongs.add(placeholder);
        localById[placeholder.id] = placeholder;
        matchedIds.add(placeholder.id);
        if (track.albumImageUrl != null) {
          artworkJobs.add(
            _cacheSpotifyArtwork(placeholder.id, track.albumImageUrl!),
          );
          if (artworkJobs.length >= 6) {
            await Future.wait(artworkJobs);
            artworkJobs.clear();
          }
        }
      }

      if (artworkJobs.isNotEmpty) await Future.wait(artworkJobs);

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
    if (_ytmusicSource == null) return;
    
    try {
      final likedSongs = await _ytmusicSource!.search('liked songs', limit: 100);
      if (likedSongs.isEmpty) return;

      final localSongs = await _db.getAllSongs();
      final matchedIds = <String>[];

      for (final track in likedSongs) {
        double bestScore = 0.3;
        String? bestId;
        for (final ls in localSongs) {
          final score = TrackMatcher.scoreWithDuration(
            track.title,
            track.artist,
            track.duration.inMilliseconds,
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
    if (_ytmusicSource == null) return;

    final syncState = await _db.getPlaylistSyncState(localPlaylistId);
    if (syncState == null || syncState['syncEnabled'] != 1) return;

    final remotePlaylistId = syncState['remotePlaylistId'] as String?;
    if (remotePlaylistId == null || remotePlaylistId.isEmpty) return;

    final direction = syncState['syncDirection'] as String? ?? 'bidirectional';
    if (direction == 'spotify_to_yt') return;

    try {
      if (addedVideoIds.isNotEmpty) {
        // Note: YouTubeMusicSource doesn't support playlist modification via API
        // This would require the backend API or Piped
        debugPrint('YT Music playlist push not implemented for added tracks');
      }
      if (removedVideoIds.isNotEmpty) {
        debugPrint('YT Music playlist push not implemented for removed tracks');
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
