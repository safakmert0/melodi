import 'package:flutter/services.dart';
import '../services/database_service.dart';

class AirPlayDevice {
  final String id;
  final String name;
  final String? model;
  final bool isAvailable;

  const AirPlayDevice({
    required this.id,
    required this.name,
    this.model,
    this.isAvailable = true,
  });

  factory AirPlayDevice.fromMap(Map<String, dynamic> map) {
    return AirPlayDevice(
      id: map['id'] as String,
      name: map['name'] as String,
      model: map['model'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }
}

class AirPlayService {
  static AirPlayService? _instance;
  static const MethodChannel _channel = MethodChannel('com.melodi/airplay');

  AirPlayService._();

  static AirPlayService get instance {
    _instance ??= AirPlayService._();
    return _instance!;
  }

  String? _currentDeviceId;

  String? get currentDeviceId => _currentDeviceId;

  Future<List<AirPlayDevice>> getAvailableDevices() async {
    try {
      final result = await _channel.invokeMethod('getAvailableDevices');
      if (result == null) return [];

      final devices = (result['devices'] as List<dynamic>?)
              ?.map((d) => AirPlayDevice.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [];
      return devices;
    } on PlatformException {
      return [];
    }
  }

  Future<bool> streamToDevice(String deviceId) async {
    try {
      final result = await _channel.invokeMethod('streamToDevice', {
        'deviceId': deviceId,
      });
      if (result == true) {
        _currentDeviceId = deviceId;
        await DatabaseService.instance.setSetting('last_airplay_device', deviceId);
        return true;
      }
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stopStreaming() async {
    try {
      await _channel.invokeMethod('stopStreaming');
      _currentDeviceId = null;
    } on PlatformException {}
  }

  Future<String?> getLastUsedDevice() async {
    return await DatabaseService.instance.getSetting('last_airplay_device');
  }

  Future<void> restoreLastUsedDevice() async {
    final lastDevice = await getLastUsedDevice();
    if (lastDevice != null) {
      await streamToDevice(lastDevice);
    }
  }
}
