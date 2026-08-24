import 'package:flutter/foundation.dart';
import '../services/metadata_service.dart';
import '../services/spotify_service.dart';
import '../services/sources/youtube_music_source.dart';

class MetadataProvider extends ChangeNotifier {
  final SpotifyService? spotifyService;
  final YouTubeMusicSource? ytmusicSource;

  MetadataProvider({this.spotifyService, this.ytmusicSource});

  bool _isBackfilling = false;
  int _backfillProgress = 0;
  int _backfillTotal = 0;
  DateTime? _lastBackfilledAt;
  String? _error;

  bool get isBackfilling => _isBackfilling;
  int get backfillProgress => _backfillProgress;
  int get backfillTotal => _backfillTotal;
  DateTime? get lastBackfilledAt => _lastBackfilledAt;
  String? get error => _error;

  Future<int> startBackfillAlbumArt() async {
    if (_isBackfilling) return 0;
    _isBackfilling = true;
    _error = null;
    _backfillProgress = 0;
    _backfillTotal = 0;
    notifyListeners();

    try {
      final count = await MetadataService.backfillAlbumArt(
        spotifyService: spotifyService,
        ytmusicSource: ytmusicSource,
      );
      _lastBackfilledAt = DateTime.now();
      _backfillProgress = count;
      _backfillTotal = count;
      return count;
    } catch (e) {
      _error = e.toString();
      return 0;
    } finally {
      _isBackfilling = false;
      notifyListeners();
    }
  }

  Future<int> startBackfillLyrics() async {
    if (_isBackfilling) return 0;
    _isBackfilling = true;
    _error = null;
    _backfillProgress = 0;
    _backfillTotal = 0;
    notifyListeners();

    try {
      final count = await MetadataService.backfillLyrics(
        ytmusicSource: ytmusicSource,
      );
      _lastBackfilledAt = DateTime.now();
      _backfillProgress = count;
      _backfillTotal = count;
      return count;
    } catch (e) {
      _error = e.toString();
      return 0;
    } finally {
      _isBackfilling = false;
      notifyListeners();
    }
  }

  Future<int> startBackfillAll() async {
    if (_isBackfilling) return 0;
    _isBackfilling = true;
    _error = null;
    _backfillProgress = 0;
    _backfillTotal = 0;
    notifyListeners();

    try {
      final count = await MetadataService.backfillAll(
        spotifyService: spotifyService,
        ytmusicSource: ytmusicSource,
      );
      _lastBackfilledAt = DateTime.now();
      _backfillProgress = count;
      _backfillTotal = count;
      return count;
    } catch (e) {
      _error = e.toString();
      return 0;
    } finally {
      _isBackfilling = false;
      notifyListeners();
    }
  }
}