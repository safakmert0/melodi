import 'package:flutter/foundation.dart';
import '../services/mix_service.dart';
import '../services/spotify_service.dart';

class MixProvider extends ChangeNotifier {
  final MixService _mixService;

  List<Map<String, dynamic>> _dailyMix = [];
  List<Map<String, dynamic>> _releaseRadar = [];
  List<Map<String, dynamic>> _discoverWeekly = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastGenerated;

  MixProvider({required SpotifyService spotifyService})
      : _mixService = MixService(spotifyService: spotifyService);

  List<Map<String, dynamic>> get dailyMix => _dailyMix;
  List<Map<String, dynamic>> get releaseRadar => _releaseRadar;
  List<Map<String, dynamic>> get discoverWeekly => _discoverWeekly;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastGenerated => _lastGenerated;

  Future<void> init() async {
    await generateAllMixes();
  }

  Future<void> generateAllMixes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _mixService.getDailyMix(),
        _mixService.getReleaseRadar(),
        _mixService.getDiscoverWeekly(),
      ]);

      _dailyMix = results[0];
      _releaseRadar = results[1];
      _discoverWeekly = results[2];
      _lastGenerated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDailyMix() async {
    _isLoading = true;
    notifyListeners();
    try {
      _dailyMix = await _mixService.getDailyMix();
      _lastGenerated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReleaseRadar() async {
    _isLoading = true;
    notifyListeners();
    try {
      _releaseRadar = await _mixService.getReleaseRadar();
      _lastGenerated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDiscoverWeekly() async {
    _isLoading = true;
    notifyListeners();
    try {
      _discoverWeekly = await _mixService.getDiscoverWeekly();
      _lastGenerated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
