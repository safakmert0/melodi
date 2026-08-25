import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../services/track_matcher.dart';
import '../services/sources/youtube_music_source.dart';
import '../services/music_source.dart';

class YTMusicPlaylist {
  final String playlistId;
  final String title;
  final String? thumbnailUrl;
  final int trackCount;

  const YTMusicPlaylist({
    required this.playlistId,
    required this.title,
    this.thumbnailUrl,
    this.trackCount = 0,
  });

  factory YTMusicPlaylist.fromJson(Map<String, dynamic> json) => YTMusicPlaylist(
    playlistId: json['playlistId'] as String,
    title: json['title'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    trackCount: json['trackCount'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'playlistId': playlistId,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'trackCount': trackCount,
  };
}

class YTMusicTrack {
  final String videoId;
  final String title;
  final String artists;
  final String? album;
  final int durationMs;
  final String? thumbnailUrl;

  const YTMusicTrack({
    required this.videoId,
    required this.title,
    required this.artists,
    this.album,
    required this.durationMs,
    this.thumbnailUrl,
  });

  factory YTMusicTrack.fromJson(Map<String, dynamic> json) => YTMusicTrack(
    videoId: json['videoId'] as String,
    title: json['title'] as String,
    artists: json['artists'] as String,
    album: json['album'] as String?,
    durationMs: json['durationMs'] as int,
    thumbnailUrl: json['thumbnailUrl'] as String?,
  );
}

class YTMusicProvider extends ChangeNotifier {
  static const _playlistKey = 'ytmusic_playlists';

  final YouTubeMusicSource _source = YouTubeMusicSource();
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _error;
  List<YTMusicPlaylist> _playlists = [];

  YouTubeMusicSource get service => _source;
  bool get isConnected => _isConnected;
  List<YTMusicPlaylist> get playlists => _playlists;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  Future<void> loadSession() async {
    try {
      final db = DatabaseService.instance;
      final saved = await db.getSetting(_playlistKey);
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        _playlists = decoded
            .map((e) => YTMusicPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('YTMusic _loadPlaylists error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final db = DatabaseService.instance;
      final encoded = jsonEncode(_playlists.map((p) => p.toJson()).toList());
      await db.setSetting(_playlistKey, encoded);
    } catch (e) {
      debugPrint('YTMusic _savePlaylists error: $e');
    }
  }

  Future<List<YTMusicPlaylist>> importPlaylists() async {
    try {
      final tracks = await _source.search('playlist', limit: 50);
      _playlists = tracks
          .where((t) => t.title.toLowerCase().contains('playlist'))
          .map((t) => YTMusicPlaylist(
                playlistId: t.id,
                title: t.title,
                thumbnailUrl: t.thumbnailUrl,
                trackCount: 0,
              ))
          .toList();
      await _savePlaylists();
      notifyListeners();
      return _playlists;
    } catch (e) {
      debugPrint('YTMusic importPlaylists error: $e');
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<YTMusicTrack>> importSongs() async {
    try {
      final tracks = await _source.search('liked songs', limit: 50);
      return tracks
          .map((t) => YTMusicTrack(
                videoId: t.id,
                title: t.title,
                artists: t.artist,
                album: t.album,
                durationMs: t.duration.inMilliseconds,
                thumbnailUrl: t.thumbnailUrl,
              ))
          .toList();
    } catch (e) {
      debugPrint('YTMusic importSongs error: $e');
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<YTMusicTrack>> getPlaylistTracks(String playlistId) async {
    try {
      final tracks = await _source.search('playlist:$playlistId', limit: 100);
      return tracks
          .map((t) => YTMusicTrack(
                videoId: t.id,
                title: t.title,
                artists: t.artist,
                album: t.album,
                durationMs: t.duration.inMilliseconds,
                thumbnailUrl: t.thumbnailUrl,
              ))
          .toList();
    } catch (e) {
      debugPrint('YTMusic getPlaylistTracks error: $e');
      return [];
    }
  }

  Future<MatchResult?> matchTrackWithConfidence(
    String title,
    String artist, {
    String? album,
    int? durationMs,
  }) async {
    try {
      final matcher = TrackMatcher();
      return await matcher.matchSpotifyTrackToYT(
        title,
        artist,
        album: album,
        durationMs: durationMs,
      );
    } catch (e) {
      debugPrint('matchTrackWithConfidence error: $e');
      return null;
    }
  }

  Future<void> disconnect() async {
    await _source.dispose();
    _isConnected = false;
    _isInitialized = false;
    _playlists.clear();
    notifyListeners();
  }

  Future<bool> connectWithCookie(String cookie) async {
    _isConnected = true;
    _isInitialized = true;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }
}