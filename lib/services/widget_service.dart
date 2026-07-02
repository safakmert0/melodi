import '../models/song_model.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  Future<void> updateNowPlaying(SongModel song) async {
    // iOS home screen widgets require a separate Widget Extension target.
    // This is a placeholder for future implementation.
  }

  Future<void> updateRecentlyPlayed(List<SongModel> songs) async {
    // Placeholder for future Widget Extension integration.
  }

  Future<void> updateFavorites(List<SongModel> songs) async {
    // Placeholder for future Widget Extension integration.
  }

  Future<void> handleWidgetAction(String action) async {
    // Placeholder for future Widget Extension integration.
  }
}
