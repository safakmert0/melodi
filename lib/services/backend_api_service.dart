import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class BackendVideo {
  final String id;
  final String title;
  final String author;
  final int duration;
  final String? thumbnail;
  final int? viewCount;

  BackendVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnail,
    this.viewCount,
  });

  factory BackendVideo.fromJson(Map<String, dynamic> json) {
    return BackendVideo(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      author: json['author'] ?? json['uploader'] ?? 'Unknown',
      duration: json['duration'] ?? 0,
      thumbnail: json['thumbnail'],
      viewCount: json['view_count'],
    );
  }
}

class BackendFormat {
  final String formatId;
  final String ext;
  final int? bitrate;
  final String quality;
  final int? filesize;

  BackendFormat({
    required this.formatId,
    required this.ext,
    this.bitrate,
    required this.quality,
    this.filesize,
  });

  factory BackendFormat.fromJson(Map<String, dynamic> json) {
    return BackendFormat(
      formatId: json['format_id'] ?? '',
      ext: json['ext'] ?? 'mp4',
      bitrate: json['bitrate'],
      quality: json['quality'] ?? 'unknown',
      filesize: json['filesize'],
    );
  }
}

class DownloadProgress {
  final double progress;
  final int downloadedBytes;
  final int? totalBytes;
  final String? speed;

  DownloadProgress({
    required this.progress,
    required this.downloadedBytes,
    this.totalBytes,
    this.speed,
  });

  String get progressLabel => '${(progress * 100).toStringAsFixed(1)}%';
}

class BackendApiService {
  String _baseUrl = 'http://localhost:8000';
  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  String get baseUrl => _baseUrl;

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Backend connection error: $e');
      return false;
    }
  }

  Future<List<BackendVideo>> search(String query, {int limit = 20}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': limit}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = (data['videos'] as List)
            .map((v) => BackendVideo.fromJson(v))
            .toList();
        return videos;
      } else {
        debugPrint('Search error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getVideoInfo(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/info/$videoId'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'info': BackendVideo.fromJson(data['info']),
          'formats': (data['formats'] as List)
              .map((f) => BackendFormat.fromJson(f))
              .toList(),
        };
      } else {
        throw Exception('Failed to get video info');
      }
    } catch (e) {
      debugPrint('Get info error: $e');
      rethrow;
    }
  }

  Future<String?> downloadAudio(
    String videoId,
    String title, {
    Function(DownloadProgress)? onProgress,
  }) async {
    try {
      final url = '$_baseUrl/api/download';
      
      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'url': 'https://www.youtube.com/watch?v=$videoId',
      });

      final streamedResponse = await http.Client().send(request)
          .timeout(const Duration(seconds: 120));

      if (streamedResponse.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final downloadDir = Directory('${dir.path}/backend_downloads');
        await downloadDir.create(recursive: true);

        final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        String safeTitle = sanitized.isEmpty ? videoId : sanitized;
        final filePath = p.join(downloadDir.path, '${safeTitle}_$videoId.m4a');
        final file = File(filePath);

        final totalBytes = streamedResponse.contentLength;
        int downloadedBytes = 0;

        final sink = file.openWrite();
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (onProgress != null) {
            final progress = totalBytes != null
                ? downloadedBytes / totalBytes
                : 0.0;
            onProgress(DownloadProgress(
              progress: progress.clamp(0.0, 1.0),
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
            ));
          }
        }
        await sink.close();

        final len = await file.length();
        debugPrint('Backend: downloaded $len bytes');

        if (len < 1000) {
          await file.delete();
          return null;
        }

        return filePath;
      } else {
        debugPrint('Download error: ${streamedResponse.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  Future<List<BackendVideo>> getPlaylist(String playlistId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/playlist/$playlistId'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = (data['videos'] as List)
            .map((v) => BackendVideo.fromJson(v))
            .toList();
        return videos;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Playlist error: $e');
      return [];
    }
  }

  void dispose() {
    _progressController.close();
  }
}
