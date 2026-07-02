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
}

class AirPlayService {
  static AirPlayService? _instance;

  AirPlayService._();

  static AirPlayService get instance {
    _instance ??= AirPlayService._();
    return _instance!;
  }

  String? _currentDeviceId;

  String? get currentDeviceId => _currentDeviceId;

  Future<List<AirPlayDevice>> getAvailableDevices() async {
    // AirPlay routing is managed natively by just_audio via AVAudioSession.
    // Users can select AirPlay targets from the iOS Control Center.
    return [];
  }

  Future<bool> streamToDevice(String deviceId) async {
    _currentDeviceId = deviceId;
    await DatabaseService.instance.setSetting('last_airplay_device', deviceId);
    return true;
  }

  Future<void> stopStreaming() async {
    _currentDeviceId = null;
  }

  Future<String?> getLastUsedDevice() async {
    return await DatabaseService.instance.getSetting('last_airplay_device');
  }

  Future<void> restoreLastUsedDevice() async {
    final lastDevice = await getLastUsedDevice();
    if (lastDevice != null) {
      _currentDeviceId = lastDevice;
    }
  }
}
