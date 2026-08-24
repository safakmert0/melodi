import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'robust_piped_service.dart';

class VideoInfo {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;
  final List<VideoFormat> formats;

  const VideoInfo({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnailUrl,
    required this.formats,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    final formats = (json['formats'] as List?)
        ?.map((f) => VideoFormat.fromJson(f))
        .where((f) => f.url.isNotEmpty)
        .toList() ??
        [];

    return VideoInfo(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      duration: Duration(seconds: json['duration'] as int? ?? 0),
      thumbnailUrl: json['thumbnail'] as String?,
      formats: formats,
    );
  }
}

class VideoFormat {
  final String itag;
  final String mimeType;
  final String quality;
  final String qualityLabel;
  final int width;
  final int height;
  final int bitrate;
  final String url;
  final bool hasAudio;
  final bool hasVideo;

  const VideoFormat({
    required this.itag,
    required this.mimeType,
    required this.quality,
    required this.qualityLabel,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.url,
    required this.hasAudio,
    required this.hasVideo,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) {
    return VideoFormat(
      itag: json['itag']?.toString() ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      qualityLabel: json['qualityLabel'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      bitrate: json['bitrate'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      hasAudio: json['hasAudio'] as bool? ?? false,
      hasVideo: json['hasVideo'] as bool? ?? false,
    );
  }
}

class VideoPlaybackService {
  VideoPlaybackService._();
  static final VideoPlaybackService _instance = VideoPlaybackService._();
  factory VideoPlaybackService() => _instance;
  static VideoPlaybackService get instance => _instance;

  final RobustPipedService _piped = RobustPipedService.instance;

  Future<VideoInfo?> getVideoInfo(String videoId) async {
    return await _piped.getVideoInfo(videoId);
  }

  Future<List<VideoFormat>> getVideoFormats(String videoId) async {
    final info = await getVideoInfo(videoId);
    if (info == null) return [];

    return info.formats
        .where((f) => f.hasVideo)
        .toList()
      ..sort((a, b) => b.height.compareTo(a.height));
  }

  Future<VideoFormat?> getBestVideoFormat(
    String videoId, {
    int maxHeight = 1080,
    bool preferMP4 = true,
  }) async {
    final formats = await getVideoFormats(videoId);
    if (formats.isEmpty) return null;

    var filtered = formats.where((f) => f.height <= maxHeight).toList();
    if (filtered.isEmpty) filtered = formats;

    if (preferMP4) {
      final mp4 = filtered.where((f) => f.mimeType.contains('mp4')).toList();
      if (mp4.isNotEmpty) filtered = mp4;
    }

    filtered.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return filtered.first;
  }

  Future<String?> getVideoStreamUrl(
    String videoId, {
    int maxHeight = 1080,
  }) async {
    final format = await getBestVideoFormat(videoId, maxHeight: maxHeight);
    return format?.url;
  }

  Future<String?> getAudioOnlyStreamUrl(String videoId) async {
    final info = await getVideoInfo(videoId);
    if (info == null) return null;

    final audioFormats = info.formats
        .where((f) => f.hasAudio && !f.hasVideo)
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    return audioFormats.isNotEmpty ? audioFormats.first.url : null;
  }

  Future<VideoInfo?> searchVideo(String query, {int limit = 10}) async {
    final tracks = await _piped.search(query, limit: limit);
    if (tracks.isEmpty) return null;
    return await getVideoInfo(tracks.first.id);
  }
}