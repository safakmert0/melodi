import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';

class DownloadQualityService {
  static final DownloadQualityService _instance = DownloadQualityService._internal();
  factory DownloadQualityService() => _instance;
  DownloadQualityService._internal();

  /// Current download quality setting
  DownloadQuality _quality = DownloadQuality.high;

  /// Get current quality setting
  DownloadQuality get quality => _quality;

  /// Set download quality
  Future<void> setQuality(DownloadQuality quality) async {
    _quality = quality;
  }

  /// Get quality as string for storage
  String getQualityString() => _quality.value;

  /// Parse quality from string
  DownloadQuality parseQualityString(String value) {
    return DownloadQuality.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DownloadQuality.high,
    );
  }

  /// Get human-readable quality name
  String getQualityDisplayName() => _quality.getDownloadDisplayName();

  /// Check if current quality is lossless
  bool get isLossless => _quality == DownloadQuality.lossless;

  /// Check if current quality is high
  bool get isHigh => _quality == DownloadQuality.high;

  /// Check if current quality is medium
  bool get isMedium => _quality == DownloadQuality.medium;

  /// Check if current quality is low
  bool get isLow => _quality == DownloadQuality.low;

  /// Get supported formats for current quality
  List<String> getSupportedFormats() {
    switch (_quality) {
      case DownloadQuality.lossless:
        return ['flac', 'wav', 'alac'];
      case DownloadQuality.high:
        return ['m4a', 'mp3', 'flac'];
      case DownloadQuality.medium:
        return ['m4a', 'mp3'];
      case DownloadQuality.low:
        return ['mp3'];
    }
  }

  /// Get bitrate recommendation for current quality
  int? getRecommendedBitrate() {
    switch (_quality) {
      case DownloadQuality.lossless:
        return null; // Lossless, no bitrate limit
      case DownloadQuality.high:
        return 320; // 320 kbps MP3 or AAC
      case DownloadQuality.medium:
        return 192; // 192 kbps
      case DownloadQuality.low:
        return 128; // 128 kbps
    }
  }
}