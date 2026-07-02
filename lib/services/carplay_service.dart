import '../models/song_model.dart';

class CarPlayService {
  static Future<void> updateNowPlaying(SongModel? song) async {
    // CarPlay is handled natively by audio_service on iOS.
    // No custom platform channel needed.
  }
}
