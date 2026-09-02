import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import 'backend_api_service.dart';
import 'extension_service.dart';
import 'robust_piped_service.dart';
import 'hls_downloader_service.dart';
import 'yt_dlp_service.dart';

class YouTubeDownloader {
  final BackendApiService _backend = BackendApiService.instance;
  final RobustPipedService _piped = RobustPipedService.instance;
  final YtDlpService _ytDlp = YtDlpService.instance;

  bool _allowDirect() {
    if (!AppConfig.disableYtDlpDirect) return true;
    try {
      return ExtensionService.instance.installed
          .any((e) => e.enabled);
    } catch (_) {
      return false;
    }
  }

  Future<String?> downloadFullTrack(
    String videoId,
    String title,
    Directory dir, {
    String quality = 'high',
  }) async {
    // 1. Backend (yt-dlp) - en iyi kalite, metadata, thumbnail
    try {
      final backendPath = await _backend.downloadAudio(videoId, title);
      if (backendPath != null) return backendPath;
    } catch (e) {
      debugPrint('Backend download failed: $e');
    }

    // 2. Robust Piped - stream URL al, indir (App Store'da sadece eklenti varsa)
    if (_allowDirect()) {
      try {
        final pipedUrl = await _piped.getStreamUrl(videoId);
        if (pipedUrl != null) {
          final path = await _downloadFromUrl(pipedUrl, title, dir);
          if (path != null) return path;
        }
      } catch (e) {
        debugPrint('Piped download failed: $e');
      }
    }

    // 3. Doğrudan YouTube (youtube_explode) - App Store'da eklenti yoksa devre dışı
    if (_allowDirect()) {
      try {
        final path = await _ytDlp.downloadAudio(videoId, title);
        if (path != null) {
          final src = File(path);
          if (await src.exists()) {
            final ext = path.split('.').last;
            final target = File('${dir.path}/${title.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}_${DateTime.now().millisecondsSinceEpoch}.$ext');
            await src.copy(target.path);
            return target.path;
          }
          return path;
        }
      } catch (e) {
        debugPrint('YtDlp download failed: $e');
      }

      // 4. Stream URL üzerinden genel indirme (yt_dlp stream URL)
      try {
        final streamUrl = await _ytDlp.getStreamUrl(videoId);
        if (streamUrl != null) {
          final path = await _downloadFromUrl(streamUrl, title, dir);
          if (path != null) return path;
        }
      } catch (e) {
        debugPrint('YtDlp stream download failed: $e');
      }
    }

    return null;
  }

  Future<String?> getStreamUrl(String videoId) async {
    try {
      final url = await _backend.streamUrl(videoId);
      if (url != null) return url;
    } catch (_) {}

    if (_allowDirect()) {
      try {
        final piped = await _piped.getStreamUrl(videoId);
        if (piped != null) return piped;
      } catch (_) {}

      try {
        return await _ytDlp.getStreamUrl(videoId);
      } catch (_) {}
    }

    return null;
  }

  /// Downloads the track as a video file (mp4/mov). Tries the native HLS
  /// downloader (native HLS) first, then the yt-dlp backend.
  Future<String?> downloadVideoTrack(
    String videoId,
    String title,
    String artist,
    Directory dir,
  ) async {
    try {
      final manifest = await _piped.getHLSManifestUrl(videoId);
      if (manifest != null) {
        final path = await HLSDownloaderService.instance.downloadHLS(
          hlsManifestUrl: manifest,
          videoId: videoId,
          title: title,
          artist: artist,
        );
        if (path != null) return path;
      }
    } catch (e) {
      debugPrint('HLS video download failed: $e');
    }

    try {
      final backendPath = await _backend.downloadVideo(videoId, title);
      if (backendPath != null) return backendPath;
    } catch (e) {
      debugPrint('Backend video download failed: $e');
    }

    return null;
  }

  Future<String?> _downloadFromUrl(
      String url, String title, Directory dir) async {
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      String safeTitle = sanitized.isEmpty ? 'download' : sanitized;

      final client = HttpClient()
        ..userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
        ..connectionTimeout = const Duration(seconds: 180);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
        final response = await request.close();
        if (response.statusCode != 200) {
          return null;
        }
        final extension = _downloadExtension(url, response.headers.contentType);
        final filePath =
            '${dir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final file = File(filePath);
        if (await file.exists()) return filePath;
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.close();
        final len = await file.length();
        if (len < 1000) {
          await file.delete();
          return null;
        }
        return filePath;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Download from URL error: $e');
      return null;
    }
  }

  String _downloadExtension(String url, ContentType? contentType) {
    final mime = contentType?.mimeType.toLowerCase();
    if (mime == 'audio/flac' || mime == 'audio/x-flac') return 'flac';
    if (mime == 'audio/mpeg' || mime == 'audio/mp3') return 'mp3';
    if (mime == 'audio/mp4' || mime == 'audio/x-m4a') return 'm4a';
    if (mime == 'audio/aac') return 'aac';
    if (mime == 'audio/ogg') return 'ogg';
    if (mime == 'audio/opus') return 'opus';
    if (mime == 'audio/wav' || mime == 'audio/x-wav') return 'wav';

    final suffix = Uri.tryParse(url)
        ?.pathSegments
        .lastOrNull
        ?.split('.')
        .last
        .toLowerCase();
    const supported = {'flac', 'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav'};
    return supported.contains(suffix) ? suffix! : 'm4a';
  }
}