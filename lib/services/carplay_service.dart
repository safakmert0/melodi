import 'package:flutter/services.dart';
import '../models/song_model.dart';

class CarPlayService {
  static const _channel = MethodChannel('com.melodi/carplay');

  static Future<void> updateNowPlaying(SongModel? song) async {
    if (song == null) return;
    try {
      await _channel.invokeMethod('setNowPlaying', {
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'durationMs': song.duration.inMilliseconds,
      });
    } catch (_) {}
  }
}
