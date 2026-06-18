import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'spotify_service.dart';
import 'ytmusic_service.dart';

class LikeMirrorService {
  final SpotifyService spotifyService;
  final YTMusicService ytMusicService;

  LikeMirrorService({
    required this.spotifyService,
    required this.ytMusicService,
  });

  Future<List<Map<String, dynamic>>> getMirroredLikes() async {
    final db = DatabaseService.instance;
    final results = await db.rawQuery(
      'SELECT * FROM mirrored_likes ORDER BY mirroredAt DESC',
    );
    return results;
  }

  Future<int> getMirroredCount() async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM mirrored_likes',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<bool> isMirrored({String? spotifyId, String? ytMusicVideoId}) async {
    final db = DatabaseService.instance;
    if (spotifyId != null && ytMusicVideoId != null) {
      final result = await db.rawQuery(
        'SELECT 1 FROM mirrored_likes WHERE spotifyId = ? AND ytMusicVideoId = ? LIMIT 1',
        [spotifyId, ytMusicVideoId],
      );
      return result.isNotEmpty;
    }
    if (spotifyId != null) {
      final result = await db.rawQuery(
        'SELECT 1 FROM mirrored_likes WHERE spotifyId = ? LIMIT 1',
        [spotifyId],
      );
      return result.isNotEmpty;
    }
    if (ytMusicVideoId != null) {
      final result = await db.rawQuery(
        'SELECT 1 FROM mirrored_likes WHERE ytMusicVideoId = ? LIMIT 1',
        [ytMusicVideoId],
      );
      return result.isNotEmpty;
    }
    return false;
  }

  Future<void> markMirrored(String spotifyId, String ytMusicVideoId) async {
    final db = DatabaseService.instance;
    await db.rawInsert(
      'INSERT OR IGNORE INTO mirrored_likes (spotifyId, ytMusicVideoId, mirroredAt) VALUES (?, ?, ?)',
      [spotifyId, ytMusicVideoId, DateTime.now().toIso8601String()],
    );
  }

  Future<bool> mirrorSpotifyToYtMusic(String spotifyTrackId) async {
    try {
      final alreadyMirrored = await isMirrored(spotifyId: spotifyTrackId);
      if (alreadyMirrored) return true;

      final tracks = await spotifyService.getLikedSongs(limit: 50);
      final track = tracks.where((t) => t.id == spotifyTrackId).firstOrNull;
      if (track == null) {
        debugPrint('LikeMirror: Spotify track $spotifyTrackId not found in likes');
        return false;
      }

      final query = '${track.name} ${track.artists.join(' ')}';
      final ytResults = await ytMusicService.search(query);
      if (ytResults.isEmpty) {
        debugPrint('LikeMirror: No YT Music match for "$query"');
        return false;
      }

      final match = ytResults.first;
      await ytMusicService.rateTrack(match.videoId, 'LIKE');
      await markMirrored(spotifyTrackId, match.videoId);
      debugPrint('LikeMirror: Mirrored Spotify $spotifyTrackId -> YT ${match.videoId}');
      return true;
    } catch (e) {
      debugPrint('LikeMirror: mirrorSpotifyToYtMusic failed: $e');
      return false;
    }
  }

  Future<bool> mirrorYtMusicToSpotify(String videoId) async {
    try {
      final alreadyMirrored = await isMirrored(ytMusicVideoId: videoId);
      if (alreadyMirrored) return true;

      final songs = await ytMusicService.getLibrarySongs();
      final song = songs.where((s) => s.videoId == videoId).firstOrNull;
      if (song == null) {
        debugPrint('LikeMirror: YT video $videoId not found in library');
        return false;
      }

      final query = '${song.title} ${song.artists}';
      final spotifyResults = await spotifyService.searchTracks(query, limit: 5);
      if (spotifyResults.isEmpty) {
        debugPrint('LikeMirror: No Spotify match for "$query"');
        return false;
      }

      final match = spotifyResults.first;
      final success = await spotifyService.likeSpotifyTrack(match.id);
      if (success) {
        await markMirrored(match.id, videoId);
        debugPrint('LikeMirror: Mirrored YT $videoId -> Spotify ${match.id}');
      }
      return success;
    } catch (e) {
      debugPrint('LikeMirror: mirrorYtMusicToSpotify failed: $e');
      return false;
    }
  }

  Future<void> checkAndMirror() async {
    debugPrint('LikeMirror: Starting checkAndMirror');

    if (!spotifyService.isConnected || !ytMusicService.isConnected) {
      debugPrint('LikeMirror: One or both services not connected');
      return;
    }

    try {
      if (spotifyService.isExpiringSoon) {
        await spotifyService.refreshAccessToken();
      }

      final spotifyLikes = await spotifyService.getLikedSongs(limit: 50);
      int mirrored = 0;

      for (final track in spotifyLikes) {
        final already = await isMirrored(spotifyId: track.id);
        if (already) continue;

        final query = '${track.name} ${track.artists.join(' ')}';
        final ytResults = await ytMusicService.search(query);
        if (ytResults.isEmpty) continue;

        final match = ytResults.first;
        await ytMusicService.rateTrack(match.videoId, 'LIKE');
        await markMirrored(track.id, match.videoId);
        mirrored++;
      }

      final ytSongs = await ytMusicService.getLibrarySongs();
      for (final song in ytSongs) {
        final already = await isMirrored(ytMusicVideoId: song.videoId);
        if (already) continue;

        final query = '${song.title} ${song.artists}';
        final spotifyResults = await spotifyService.searchTracks(query, limit: 5);
        if (spotifyResults.isEmpty) continue;

        final match = spotifyResults.first;
        final success = await spotifyService.likeSpotifyTrack(match.id);
        if (success) {
          await markMirrored(match.id, song.videoId);
          mirrored++;
        }
      }

      debugPrint('LikeMirror: checkAndMirror completed, mirrored $mirrored new tracks');
    } catch (e) {
      debugPrint('LikeMirror: checkAndMirror failed: $e');
    }
  }
}
