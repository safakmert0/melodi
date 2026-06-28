import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';

class BluetoothService {
  static BluetoothService? _instance;
  static BluetoothService get instance => _instance ??= BluetoothService._();
  BluetoothService._();

  final DatabaseService _db = DatabaseService.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  String? _lastDeviceName;
  bool _isBluetoothConnected = false;

  static const String _kBluetoothDeviceKey = 'bluetooth_connected_device';
  static const String _kAutoEqEnabledKey = 'bluetooth_auto_eq_enabled';
  static const String _kDevicePresetPrefix = 'bt_preset_';

  bool get isBluetoothConnected => _isBluetoothConnected;
  String? get connectedDeviceName => _lastDeviceName;

  Future<void> detectBluetoothConnection() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityResults(results);

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityResults);
  }

  void _handleConnectivityResults(List<ConnectivityResult> results) {
    final wasConnected = _isBluetoothConnected;
    _isBluetoothConnected = results.any((r) => r == ConnectivityResult.bluetooth);

    if (_isBluetoothConnected && !wasConnected) {
      _onBluetoothConnected();
    } else if (!_isBluetoothConnected && wasConnected) {
      _onBluetoothDisconnected();
    }
  }

  Future<void> _onBluetoothConnected() async {
    _lastDeviceName = await _db.getSetting(_kBluetoothDeviceKey);
    debugPrint('Bluetooth connected: ${_lastDeviceName ?? "unknown device"}');

    final autoEqEnabled = await _db.getSetting(_kAutoEqEnabledKey);
    if (autoEqEnabled == 'true' && _lastDeviceName != null) {
      await autoApplyEQ(_lastDeviceName!);
    }
  }

  Future<void> _onBluetoothDisconnected() async {
    debugPrint('Bluetooth disconnected');
    _lastDeviceName = null;
  }

  Future<void> autoApplyEQ(String deviceName) async {
    final presetKey = '$_kDevicePresetPrefix$deviceName';
    final preset = await _db.getSetting(presetKey);

    if (preset == null) {
      final fallbackPreset = _guessPresetForDevice(deviceName);
      await _db.setSetting(presetKey, fallbackPreset);
      debugPrint('Auto EQ: applied fallback preset "$fallbackPreset" for "$deviceName"');
      return;
    }

    debugPrint('Auto EQ: applied saved preset "$preset" for "$deviceName"');
  }

  String _guessPresetForDevice(String deviceName) {
    final lower = deviceName.toLowerCase();

    if (lower.contains('airpod') || lower.contains('earbuds') || lower.contains('buds')) {
      return 'bass_boost';
    }
    if (lower.contains('speaker') || lower.contains('homepod') || lower.contains('echo')) {
      return 'flat';
    }
    if (lower.contains('car') || lower.contains('auto') || lower.contains('drive')) {
      return 'vocal';
    }
    if (lower.contains('headphone') || lower.contains('headset') || lower.contains('sony') ||
        lower.contains('bose') || lower.contains('sennheiser')) {
      return 'audiophile';
    }

    return 'flat';
  }

  Future<void> saveDevicePreset(String deviceName, String preset) async {
    final presetKey = '$_kDevicePresetPrefix$deviceName';
    await _db.setSetting(presetKey, preset);
  }

  Future<String?> getDevicePreset(String deviceName) async {
    final presetKey = '$_kDevicePresetPrefix$deviceName';
    return await _db.getSetting(presetKey);
  }

  Future<void> setAutoEqEnabled(bool enabled) async {
    await _db.setSetting(_kAutoEqEnabledKey, enabled.toString());
  }

  Future<bool> isAutoEqEnabled() async {
    final value = await _db.getSetting(_kAutoEqEnabledKey);
    return value == 'true';
  }

  Future<void> setConnectedDeviceName(String name) async {
    _lastDeviceName = name;
    await _db.setSetting(_kBluetoothDeviceKey, name);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
