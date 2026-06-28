import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/song_model.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.melodi/widgets');

  Future<void> updateNowPlaying(SongModel song) async {
    await _channel.invokeMethod('updateNowPlaying', {
      'title': song.title,
      'artist': song.artist,
      'albumArt': song.albumArt,
      'duration': song.duration,
      'position': 0,
      'isPlaying': false,
    });
  }

  Future<void> updateRecentlyPlayed(List<SongModel> songs) async {
    final data = songs.take(10).map((s) => {
      'title': s.title,
      'artist': s.artist,
      'albumArt': s.albumArt,
    }).toList();

    await _channel.invokeMethod('updateRecentlyPlayed', {
      'songs': data,
    });
  }

  Future<void> updateFavorites(List<SongModel> songs) async {
    final data = songs.take(10).map((s) => {
      'title': s.title,
      'artist': s.artist,
      'albumArt': s.albumArt,
    }).toList();

    await _channel.invokeMethod('updateFavorites', {
      'songs': data,
    });
  }

  Future<void> handleWidgetAction(String action) async {
    await _channel.invokeMethod('handleWidgetAction', {
      'action': action,
    });
  }
}
