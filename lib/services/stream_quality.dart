import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'audio_quality_service.dart';

/// Kalite ayari -> bitrate tavani (kbps). null = sinirsiz (en iyi).
int? qualityCapKbps(String quality) {
  switch (quality.trim().toLowerCase()) {
    case 'low':
      return 48;
    case 'normal':
      return 128;
    case 'high':
      return 256;
    case 'lossless':
    case 'auto':
    default:
      return null;
  }
}

Future<bool> _isCellular() async {
  try {
    final conn = await Connectivity()
        .checkConnectivity()
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    return conn.contains(ConnectivityResult.mobile) &&
        !conn.contains(ConnectivityResult.wifi) &&
        !conn.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return false;
  }
}

/// Akis kalitesi: hucrede hucre ayari, degilse wifi/akış ayari.
Future<String> effectiveStreamingQuality() async {
  final svc = AudioQualityService();
  if (await _isCellular()) {
    try {
      return await svc.getCellularQuality();
    } catch (_) {}
  }
  try {
    final wifi = await svc.getWifiQuality();
    if (wifi.isNotEmpty) return wifi;
  } catch (_) {}
  try {
    return await svc.getStreamingQuality();
  } catch (e) {
    debugPrint('stream quality read error: $e');
    return 'lossless';
  }
}

/// Indirme kalitesi: hucrede hucre ayari, degilse indirme ayari.
Future<String> effectiveDownloadQuality() async {
  final svc = AudioQualityService();
  if (await _isCellular()) {
    try {
      return await svc.getCellularQuality();
    } catch (_) {}
  }
  try {
    return await svc.getDownloadQuality();
  } catch (e) {
    debugPrint('download quality read error: $e');
    return 'lossless';
  }
}
