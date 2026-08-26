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
  int _backfillFailed = 0;
  DateTime? _lastBackfilledAt;
  String? _error;
  List<String> _backfillErrors = [];
  String? _backfillSummary;

  bool get isBackfilling => _isBackfilling;
  int get backfillProgress => _backfillProgress;
  int get backfillTotal => _backfillTotal;
  int get backfillFailed => _backfillFailed;
  DateTime? get lastBackfilledAt => _lastBackfilledAt;
  String? get error => _error;
  List<String> get backfillErrors => List.unmodifiable(_backfillErrors);
  String? get backfillSummary => _backfillSummary;

  void _reset() {
    _isBackfilling = true;
    _error = null;
    _backfillProgress = 0;
    _backfillTotal = 0;
    _backfillFailed = 0;
    _backfillErrors = [];
    _backfillSummary = null;
    notifyListeners();
  }

  String _summarize(BackfillReport report, String label) {
    final failed = report.failures.length;
    return failed == 0
        ? '$label: ${report.updated}/${report.total} completed'
        : '$label: ${report.updated}/${report.total} completed, '
            '$failed failed';
  }

  Future<int> startBackfillAlbumArt() async {
    if (_isBackfilling) return 0;
    _reset();

    try {
      final report = await MetadataService.backfillAlbumArt(
        spotifyService: spotifyService,
        ytmusicSource: ytmusicSource,
      );
      _lastBackfilledAt = DateTime.now();
      _backfillProgress = report.updated;
      _backfillTotal = report.total;
      _backfillFailed = report.failures.length;
      _backfillErrors = report.failures;
      _backfillSummary = _summarize(report, 'Album art');
      return report.updated;
    } catch (e) {
      _error = e.toString();
      _backfillErrors = [e.toString()];
      return 0;
    } finally {
      _isBackfilling = false;
      notifyListeners();
    }
  }

  Future<int> startBackfillLyrics() async {
    if (_isBackfilling) return 0;
    _reset();

    try {
      final report = await MetadataService.backfillLyrics(
        ytmusicSource: ytmusicSource,
      );
      _lastBackfilledAt = DateTime.now();
      _backfillProgress = report.updated;
      _backfillTotal = report.total;
      _backfillFailed = report.failures.length;
      _backfillErrors = report.failures;
      _backfillSummary = _summarize(report, 'Lyrics');
      return report.updated;
    } catch (e) {
      _error = e.toString();
      _backfillErrors = [e.toString()];
      return 0;
    } finally {
      _isBackfilling = false;
      notifyListeners();
    }
  }

  Future<int> startBackfillAll() async {
    if (_isBackfilling) return 0;
    _reset();

    try {
      final report = await MetadataService.backfillAll(
        spotifyService: spotifyService,
        ytmusicSource: ytmusicSource,
      );
      _lastBackfilledAt = DateTime.now();
      _backfillProgress = report.updated;
      _backfillTotal = report.total;
      _backfillFailed = report.failures.length;
      _backfillErrors = report.failures;
      _backfillSummary = _summarize(report, 'Backfill');
      return report.updated;
    } catch (e) {
      _error = e.toString();
      _backfillErrors = [e.toString()];
      return 0;
    } finally {
      _isBackfilling = false;
      notifyListeners();
    }
  }
}
