import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CastDevice {
  final String id;
  final String name;
  final String type;
  final String? model;
  final String? manufacturer;

  const CastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.model,
    this.manufacturer,
  });

  bool get isChromecast => type == 'chromecast';
  bool get isAirPlay => type == 'airplay';
}

class CastSession {
  final String sessionId;
  final CastDevice device;
  final DateTime startedAt;
  String status;
  String? currentTrackId;
  Duration position;
  Duration duration;
  double volume;

  CastSession({
    required this.sessionId,
    required this.device,
    required this.startedAt,
    this.status = 'connecting',
    this.currentTrackId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
  });
}

class CastService {
  CastService._();
  static final CastService _instance = CastService._();
  factory CastService() => _instance;
  static CastService get instance => _instance;

  static const MethodChannel _channel = MethodChannel('com.melodi.cast');

  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();
  final StreamController<CastSession?> _sessionController =
      StreamController<CastSession?>.broadcast();

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  Stream<CastSession?> get sessionStream => _sessionController.stream;

  List<CastDevice> _devices = [];
  CastSession? _currentSession;
  Timer? _discoveryTimer;
  Timer? _sessionUpdateTimer;

  List<CastDevice> get devices => List.unmodifiable(_devices);
  CastSession? get currentSession => _currentSession;
  bool get isCasting => _currentSession != null;

  Future<void> initialize() async {
    await _startDiscovery();
    _listenToNativeEvents();
  }

  Future<void> _startDiscovery() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _discoverDevices();
    });
    await _discoverDevices();
  }

  Future<void> _discoverDevices() async {
    try {
      final result = await _channel.invokeMethod('discoverDevices');
      if (result is List) {
        _devices = result
            .whereType<Map>()
            .map((d) => CastDevice(
                  id: d['id'] as String,
                  name: d['name'] as String,
                  type: d['type'] as String,
                  model: d['model'] as String?,
                  manufacturer: d['manufacturer'] as String?,
                ))
            .toList();
        _devicesController.add(List.from(_devices));
      }
    } catch (e) {
      debugPrint('Cast discovery error: $e');
    }
  }

  void _listenToNativeEvents() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDeviceFound':
          final device = CastDevice(
            id: call.arguments['id'],
            name: call.arguments['name'],
            type: call.arguments['type'],
            model: call.arguments['model'],
            manufacturer: call.arguments['manufacturer'],
          );
          if (!_devices.any((d) => d.id == device.id)) {
            _devices.add(device);
            _devicesController.add(List.from(_devices));
          }
          break;
        case 'onDeviceLost':
          final id = call.arguments['id'] as String;
          _devices.removeWhere((d) => d.id == id);
          _devicesController.add(List.from(_devices));
          break;
        case 'onSessionStarted':
          _currentSession = CastSession(
            sessionId: call.arguments['sessionId'],
            device: _devices.firstWhere((d) => d.id == call.arguments['deviceId']),
            startedAt: DateTime.now(),
            status: 'playing',
          );
          _sessionController.add(_currentSession);
          _startSessionUpdates();
          break;
        case 'onSessionEnded':
          _currentSession = null;
          _sessionController.add(null);
          _stopSessionUpdates();
          break;
        case 'onSessionUpdate':
          if (_currentSession != null) {
            _currentSession = _currentSession!.copyWith(
              status: call.arguments['status'],
              currentTrackId: call.arguments['trackId'],
              position: Duration(milliseconds: call.arguments['position'] ?? 0),
              duration: Duration(milliseconds: call.arguments['duration'] ?? 0),
              volume: (call.arguments['volume'] as num?)?.toDouble() ?? 1.0,
            );
            _sessionController.add(_currentSession);
          }
          break;
      }
    });
  }

  Future<bool> castToDevice(CastDevice device, {
    required String trackId,
    required String title,
    required String artist,
    required String streamUrl,
    String? artworkUrl,
    int? durationMs,
  }) async {
    try {
      await _channel.invokeMethod('startSession', {
        'deviceId': device.id,
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'streamUrl': streamUrl,
        'artworkUrl': artworkUrl,
        'durationMs': durationMs,
      });
      return true;
    } catch (e) {
      debugPrint('Cast start error: $e');
      return false;
    }
  }

  Future<void> stopCasting() async {
    try {
      await _channel.invokeMethod('stopSession');
    } catch (e) {
      debugPrint('Cast stop error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('Cast pause error: $e');
    }
  }

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('Cast play error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _channel.invokeMethod('seek', {'position': position.inMilliseconds});
    } catch (e) {
      debugPrint('Cast seek error: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
    } catch (e) {
      debugPrint('Cast volume error: $e');
    }
  }

  Future<void> nextTrack() async {
    try {
      await _channel.invokeMethod('nextTrack');
    } catch (e) {
      debugPrint('Cast next error: $e');
    }
  }

  Future<void> previousTrack() async {
    try {
      await _channel.invokeMethod('previousTrack');
    } catch (e) {
      debugPrint('Cast previous error: $e');
    }
  }

  void _startSessionUpdates() {
    _sessionUpdateTimer?.cancel();
    _sessionUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_currentSession != null) {
        _channel.invokeMethod('getSessionStatus');
      }
    });
  }

  void _stopSessionUpdates() {
    _sessionUpdateTimer?.cancel();
    _sessionUpdateTimer = null;
  }

  void dispose() {
    _discoveryTimer?.cancel();
    _sessionUpdateTimer?.cancel();
    _devicesController.close();
    _sessionController.close();
  }
}

extension CastSessionCopyWith on CastSession {
  CastSession copyWith({
    String? sessionId,
    CastDevice? device,
    DateTime? startedAt,
    String? status,
    String? currentTrackId,
    Duration? position,
    Duration? duration,
    double? volume,
  }) {
    return CastSession(
      sessionId: sessionId ?? this.sessionId,
      device: device ?? this.device,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      currentTrackId: currentTrackId ?? this.currentTrackId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
    );
  }
}