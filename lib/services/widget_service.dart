import 'package:flutter/services.dart';
import '../models/song_model.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.melodi/widgets');

  Future<void> updateNowPlaying(SongModel song) async {
    try {
      await _channel.invokeMethod('updateNowPlaying', {
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'albumArt': song.albumArt != null ? 'has_art' : '',
        'duration': song.duration.inMilliseconds,
        'position': 0,
        'isPlaying': false,
      });
    } catch (_) {}
  }

  Future<void> updateRecentlyPlayed(List<SongModel> songs) async {
    try {
      final data = songs.take(10).map((s) => {
        'title': s.title,
        'artist': s.artist,
      }).toList();

      await _channel.invokeMethod('updateRecentlyPlayed', {
        'songs': data,
      });
    } catch (_) {}
  }

  Future<void> updateFavorites(List<SongModel> songs) async {
    try {
      final data = songs.take(10).map((s) => {
        'title': s.title,
        'artist': s.artist,
      }).toList();

      await _channel.invokeMethod('updateFavorites', {
        'songs': data,
      });
    } catch (_) {}
  }

  Future<void> handleWidgetAction(String action) async {
    try {
      await _channel.invokeMethod('handleWidgetAction', {
        'action': action,
      });
    } catch (_) {}
  }
}
