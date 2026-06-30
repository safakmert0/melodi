import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/spotify_service.dart';
import '../services/ytmusic_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final SpotifyService _spotifyService;
  final YTMusicService _ytmusicService;
  Timer? _timer;

  bool _spotifyConnected = false;
  bool _ytMusicConnected = false;
  bool _spotifyExpired = false;
  bool _ytMusicExpired = false;
  bool _dismissed = false;

  bool get spotifyConnected => _spotifyConnected;
  bool get ytMusicConnected => _ytMusicConnected;
  bool get spotifyExpired => _spotifyExpired;
  bool get ytMusicExpired => _ytMusicExpired;
  bool get anyExpired => _spotifyExpired || _ytMusicExpired;
  bool get shouldShowBanner => anyExpired && !_dismissed;

  ConnectionProvider({
    required SpotifyService spotifyService,
    required YTMusicService ytmusicService,
  })  : _spotifyService = spotifyService,
        _ytmusicService = ytmusicService;

  Future<void> init() async {
    try {
      await loadState();
      await checkConnections().timeout(const Duration(seconds: 15));
    } catch (_) {}
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => checkConnections());
  }

  Future<void> checkConnections() async {
    _dismissed = false;

    _spotifyConnected = _spotifyService.isConnected;
    if (_spotifyConnected) {
      try {
        final session = await _spotifyService.refreshAccessToken().timeout(const Duration(seconds: 10));
        if (session == null) {
          _spotifyExpired = true;
          _spotifyConnected = false;
        } else {
          _spotifyExpired = false;
        }
      } catch (_) {
        _spotifyExpired = true;
        _spotifyConnected = false;
      }
    } else {
      _spotifyExpired = false;
    }

    _ytMusicConnected = _ytmusicService.isConnected;
    if (_ytMusicConnected) {
      try {
        final response = await _ytmusicService.client.browse('FEmusic_liked_playlists')
            .timeout(const Duration(seconds: 10));
        if (response == null) {
          _ytMusicExpired = true;
          _ytMusicConnected = false;
        } else {
          _ytMusicExpired = false;
        }
      } catch (_) {
        _ytMusicExpired = true;
        _ytMusicConnected = false;
      }
    } else {
      _ytMusicExpired = false;
    }

    await _saveState();
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    await checkConnections();
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  Future<void> _saveState() async {
    final db = DatabaseService.instance;
    await db.setSetting('spotify_connected', _spotifyConnected ? '1' : '0');
    await db.setSetting('ytmusic_connected', _ytMusicConnected ? '1' : '0');
    await db.setSetting('spotify_expired', _spotifyExpired ? '1' : '0');
    await db.setSetting('ytmusic_expired', _ytMusicExpired ? '1' : '0');
  }

  Future<void> loadState() async {
    final db = DatabaseService.instance;
    _spotifyConnected = (await db.getSetting('spotify_connected')) == '1';
    _ytMusicConnected = (await db.getSetting('ytmusic_connected')) == '1';
    _spotifyExpired = (await db.getSetting('spotify_expired')) == '1';
    _ytMusicExpired = (await db.getSetting('ytmusic_expired')) == '1';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
