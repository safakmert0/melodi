import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class YtDlpVideo {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;
  final String? description;
  final DateTime? uploadDate;
  final int? viewCount;

  YtDlpVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnailUrl,
    this.description,
    this.uploadDate,
    this.viewCount,
  });

  factory YtDlpVideo.fromVideo(Video video) {
    return YtDlpVideo(
      id: video.id.value,
      title: video.title,
      author: video.author,
      duration: video.duration ?? Duration.zero,
      thumbnailUrl: video.thumbnails.standardResUrl,
      description: video.description,
      uploadDate: video.uploadDate,
      viewCount: video.engagement.viewCount,
    );
  }
}

class AudioFormat {
  final String container;
  final int bitrate;
  final int? sampleRate;
  final String codec;
  final AudioOnlyStreamInfo streamInfo;

  AudioFormat({
    required this.container,
    required this.bitrate,
    this.sampleRate,
    required this.codec,
    required this.streamInfo,
  });

  String get bitrateLabel {
    final kbps = bitrate ~/ 1000;
    return '${kbps}kbps';
  }

  String get qualityLabel {
    if (bitrate >= 256000) return 'Yüksek Kalite';
    if (bitrate >= 128000) return 'Orta Kalite';
    return 'Düşük Kalite';
  }
}

class DownloadProgress {
  final double progress;
  final int downloadedBytes;
  final int? totalBytes;
  final Duration? estimatedTime;
  final String? speed;

  DownloadProgress({
    required this.progress,
    required this.downloadedBytes,
    this.totalBytes,
    this.estimatedTime,
    this.speed,
  });

  String get progressLabel => '${(progress * 100).toStringAsFixed(1)}%';
  
  String get sizeLabel {
    if (totalBytes == null) return '';
    if (totalBytes! < 1024) return '$totalBytes B';
    if (totalBytes! < 1024 * 1024) return '${(totalBytes! / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class YtDlpService {
  YoutubeExplode? _yt;
  final StreamController<DownloadProgress> _progressController = 
      StreamController<DownloadProgress>.broadcast();

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _downloadTimeout = Duration(seconds: 180);
  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  static final List<YoutubeApiClient> _clients = [
    YoutubeApiClient.ios,
    YoutubeApiClient.android,
    YoutubeApiClient.safari,
  ];

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  YoutubeExplode get _client {
    _yt ??= YoutubeExplode();
    return _yt!;
  }

  Future<String?> extractVideoId(String input) async {
    final trimmed = input.trim();
    
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null) return match.group(1);
    }

    return null;
  }

  Future<YtDlpVideo?> getVideoInfo(String input) async {
    try {
      final videoId = await extractVideoId(input);
      if (videoId == null) return null;

      final video = await _client.videos.get(videoId).timeout(_timeout);
      return YtDlpVideo.fromVideo(video);
    } catch (e) {
      debugPrint('YtDlpService getVideoInfo error: $e');
      return null;
    }
  }

  Future<List<YtDlpVideo>> search(String query, {int limit = 20}) async {
    try {
      final results = await _client.search.search(query).timeout(_timeout);
      final videos = <YtDlpVideo>[];
      
      for (final video in results) {
        if (video.duration != null && video.duration!.inSeconds > 0) {
          videos.add(YtDlpVideo.fromVideo(video));
        }
        if (videos.length >= limit) break;
      }
      
      return videos;
    } catch (e) {
      debugPrint('YtDlpService search error: $e');
      return [];
    }
  }

  Future<List<AudioFormat>> getAvailableFormats(String videoId) async {
    final formats = <AudioFormat>[];
    
    for (final client in _clients) {
      try {
        final manifest = await _client.videos.streams
            .getManifest(videoId, ytClients: [client])
            .timeout(_timeout);
        
        final audioStreams = manifest.audioOnly;
        
        for (final stream in audioStreams) {
          formats.add(AudioFormat(
            container: stream.container.name,
            bitrate: stream.bitrate.bitsPerSecond,
            sampleRate: stream.sampleRate,
            codec: stream.audioCodec,
            streamInfo: stream,
          ));
        }
        
        if (formats.isNotEmpty) break;
      } catch (e) {
        debugPrint('YtDlpService getAvailableFormats $client error: $e');
      }
    }

    formats.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return formats;
  }

  AudioFormat selectBestFormat(List<AudioFormat> formats) {
    if (formats.isEmpty) throw Exception('No audio formats available');

    final m4aFormats = formats.where((f) => f.container == 'mp4').toList();
    if (m4aFormats.isNotEmpty) {
      return m4aFormats.first;
    }

    return formats.first;
  }

  Future<String?> downloadAudio(
    String videoId,
    String title, {
    AudioFormat? preferredFormat,
    Function(DownloadProgress)? onProgress,
  }) async {
    try {
      final formats = await getAvailableFormats(videoId);
      if (formats.isEmpty) return null;

      final format = preferredFormat ?? selectBestFormat(formats);
      final stream = format.streamInfo;

      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      String safeTitle = sanitized.isEmpty ? videoId : sanitized;
      
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/yt_downloads');
      await downloadDir.create(recursive: true);
      
      final filePath = p.join(downloadDir.path, '${safeTitle}_$videoId.m4a');
      final file = File(filePath);
      
      if (await file.exists()) {
        final len = await file.length();
        if (len > 1000) return filePath;
      }

      final httpClient = HttpClient()
        ..userAgent = _userAgent
        ..connectionTimeout = _downloadTimeout;

      try {
        final request = await httpClient.getUrl(stream.url);
        request.headers.set('User-Agent', _userAgent);
        
        final response = await request.close();
        if (response.statusCode != 200) {
          debugPrint('YtDlpService download HTTP ${response.statusCode}');
          return null;
        }

        final totalBytes = response.contentLength;
        int downloadedBytes = 0;
        final startTime = DateTime.now();

        final sink = file.openWrite();
        await for (final chunk in response) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (onProgress != null) {
            final elapsed = DateTime.now().difference(startTime);
            final speed = downloadedBytes / elapsed.inSeconds;
            final progress = totalBytes != null 
                ? downloadedBytes / totalBytes 
                : 0.0;
            
            Duration? estimatedTime;
            if (totalBytes != null && speed > 0) {
              final remaining = (totalBytes - downloadedBytes) / speed;
              estimatedTime = Duration(seconds: remaining.toInt());
            }

            onProgress(DownloadProgress(
              progress: progress.clamp(0.0, 1.0),
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              estimatedTime: estimatedTime,
              speed: _formatSpeed(speed),
            ));
          }
        }

        await sink.close();
        await httpClient.close();

        final len = await file.length();
        debugPrint('YtDlpService: downloaded ${len} bytes');
        
        if (len < 1000) {
          await file.delete();
          debugPrint('YtDlpService: file too small, deleted');
          return null;
        }

        return filePath;
      } catch (e) {
        await httpClient.close();
        rethrow;
      }
    } catch (e) {
      debugPrint('YtDlpService downloadAudio error: $e');
      return null;
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Future<List<YtDlpVideo>> getPlaylistVideos(String playlistUrl) async {
    try {
      final playlistId = _extractPlaylistId(playlistUrl);
      if (playlistId == null) return [];

      final playlist = await _client.playlists.get(playlistId).timeout(_timeout);
      final videos = <YtDlpVideo>[];

      await for (final video in _client.playlists.getVideos(playlistId)) {
        videos.add(YtDlpVideo.fromVideo(video));
        if (videos.length >= 100) break;
      }

      return videos;
    } catch (e) {
      debugPrint('YtDlpService getPlaylistVideos error: $e');
      return [];
    }
  }

  String? _extractPlaylistId(String url) {
    final pattern = RegExp(r'list=([a-zA-Z0-9_-]+)');
    final match = pattern.firstMatch(url);
    return match?.group(1);
  }

  Future<void> dispose() async {
    await _progressController.close();
    _yt?.close();
  }
}
