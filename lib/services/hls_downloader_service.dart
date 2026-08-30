import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/app_config.dart';
import '../models/extension.dart';
import 'database_service.dart';
import 'extension_service.dart';
import 'storage_manager.dart';
import 'backend_api_service.dart';
import 'robust_piped_service.dart';
import 'metadata_service.dart';

/// iOS Native HLS Downloader using AVAssetDownloadTask
/// Uses AVAssetDownloadURLSession for background HLS segment downloading with FairPlay support
class HLSDownloaderService {
  HLSDownloaderService._();
  static final HLSDownloaderService _instance = HLSDownloaderService._();
  factory HLSDownloaderService() => _instance;
  static HLSDownloaderService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;
  final StorageManager _storage = StorageManager.instance;
  
  static const MethodChannel _channel = MethodChannel('com.melodi/hls_downloader');

  // Active downloads tracking
  final Map<String, _HLSDownloadTask> _activeDownloads = {};
  final StreamController<Map<String, _HLSDownloadTask>> _progressController =
      StreamController<Map<String, _HLSDownloadTask>>.broadcast();

  Stream<Map<String, _HLSDownloadTask>> get progressStream => _progressController.stream;
  Map<String, _HLSDownloadTask> get activeDownloads => Map.unmodifiable(_activeDownloads);

  /// Download HLS stream to local file
  /// Returns local file path on success, null on failure
  /// App Store'da eklentisiz bloklu (YouTube indirme).
  Future<String?> downloadHLS({
    required String hlsManifestUrl,
    required String videoId,
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
    int? expectedDurationMs,
    Function(double progress)? onProgress,
  }) async {
    if (AppConfig.disableYtDlpDirect) {
      try {
        final hasBackend = ExtensionService.instance.installed
            .any((e) => e.enabled && e.manifest.kind == ExtensionKind.backend);
        if (!hasBackend) {
          debugPrint('HLS download blocked: App Store mode without extension');
          return null;
        }
      } catch (_) {
        return null;
      }
    }
    try {
      final downloadId = videoId;
      
      // Check if already downloading
      if (_activeDownloads.containsKey(downloadId)) {
        debugPrint('HLS download already in progress for $videoId');
        return null;
      }

      // Prepare destination
      final downloadDir = Directory(await _storage.getStorageLocation());
      await downloadDir.create(recursive: true);
      
      final sanitizedTitle = _sanitizeFilename(title);
      final sanitizedArtist = _sanitizeFilename(artist);
      final fileName = '${sanitizedArtist} - $sanitizedTitle';
      final destinationPath = p.join(downloadDir.path, '${fileName}_$videoId.mp4');

      // Check if already exists
      if (await File(destinationPath).exists()) {
        debugPrint('HLS file already exists: $destinationPath');
        return destinationPath;
      }

      // Create download task
      final task = _HLSDownloadTask(
        id: downloadId,
        hlsManifestUrl: hlsManifestUrl,
        videoId: videoId,
        title: title,
        artist: artist,
        album: album,
        artworkUrl: artworkUrl,
        destinationPath: destinationPath,
        expectedDurationMs: expectedDurationMs,
        onProgress: onProgress,
      );

      _activeDownloads[downloadId] = task;
      _notifyProgress();

      // Start native download via platform channel
      try {
        await _channel.invokeMethod('startHLSDownload', {
          'videoId': task.videoId,
          'hlsManifestUrl': task.hlsManifestUrl,
          'destinationPath': task.destinationPath,
          'title': task.title,
          'artist': task.artist,
        });
      } on PlatformException catch (e) {
        debugPrint('Platform error starting HLS download: $e');
        _activeDownloads.remove(downloadId);
        _notifyProgress();
        return null;
      }

      // Wait for completion
      final resultPath = await task.completion.future;
      
      if (resultPath != null && await File(resultPath).exists()) {
        // Import to library
        final importedPath = await _importDownloadedFile(resultPath, task);
        
        // Save to database
        await _db.upsertDownloadedTrack(videoId, importedPath ?? resultPath);
        
        _activeDownloads.remove(downloadId);
        _notifyProgress();
        
        return importedPath ?? resultPath;
      }

      _activeDownloads.remove(downloadId);
      _notifyProgress();
      return null;
    } catch (e) {
      debugPrint('HLS download error: $e');
      _activeDownloads.remove(videoId);
      _notifyProgress();
      return null;
    }
  }

  /// Get HLS manifest URL from various sources
  Future<String?> getHLSManifestUrl(String videoId) async {
    // 1. Try Backend API (yt-dlp)
    try {
      final backendUrl = await BackendApiService.instance.streamUrl(videoId);
      if (backendUrl != null && backendUrl.contains('.m3u8')) {
        return backendUrl;
      }
    } catch (_) {}

    // 2. Try Piped instances (HLS)
    try {
      final pipedUrl = await RobustPipedService.instance.getHLSManifestUrl(videoId);
      if (pipedUrl != null) return pipedUrl;
    } catch (_) {}

    // 3. Try Invidious instances
    try {
      final invidiousUrl = await RobustPipedService.instance.getInvidiousHLSUrl(videoId);
      if (invidiousUrl != null) return invidiousUrl;
    } catch (_) {}

    // 4. Construct YouTube HLS URL directly (fallback)
    return 'https://manifest.googlevideo.com/api/manifest/hls_variant/$videoId';
  }

  /// Stream HLS directly (for playback without full download)
  Future<String?> getHLSStreamUrl(String videoId) async {
    return await getHLSManifestUrl(videoId);
  }

  /// Cancel active download
  Future<void> cancelDownload(String videoId) async {
    final task = _activeDownloads[videoId];
    if (task != null) {
      try {
        await _channel.invokeMethod('cancelHLSDownload', {'videoId': videoId});
      } on PlatformException catch (e) {
        debugPrint('Platform error canceling HLS download: $e');
      }
      task.completion.complete(null);
      _activeDownloads.remove(videoId);
      _notifyProgress();
    }
  }

  /// Cancel all downloads
  Future<void> cancelAllDownloads() async {
    for (final videoId in _activeDownloads.keys.toList()) {
      await cancelDownload(videoId);
    }
  }

  /// Get download progress for a video
  double getProgress(String videoId) {
    return _activeDownloads[videoId]?.progress ?? 0.0;
  }

  bool isDownloading(String videoId) {
    return _activeDownloads.containsKey(videoId);
  }

  Future<String?> _importDownloadedFile(String filePath, _HLSDownloadTask task) async {
    try {
      final musicDir = Directory(await _storage.getStorageLocation());
      await musicDir.create(recursive: true);

      final ext = 'mp4'; // HLS downloads are MP4 containers
      final safeName = '${task.artist} - ${task.title}'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      var destPath = '${musicDir.path}/$safeName.$ext';
      var counter = 1;
      while (File(destPath).existsSync()) {
        destPath = '${musicDir.path}/$safeName ($counter).$ext';
        counter++;
      }

      final sourceFile = File(filePath);
      await sourceFile.rename(destPath);

      // Update metadata
      final metadata = await MetadataService.extractMetadata(destPath);
      if (metadata != null) {
        final updated = metadata.copyWith(
          id: task.videoId,
          title: task.title,
          artist: task.artist,
          album: task.album,
          filePath: destPath,
          albumArt: null,
          fileSize: await File(destPath).length(),
        );
        await DatabaseService.instance.insertSong(updated);
      }

      return destPath;
    } catch (e) {
      debugPrint('Import HLS file error: $e');
      return filePath;
    }
  }

  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _notifyProgress() {
    _progressController.add(Map.from(_activeDownloads));
  }

  void dispose() {
    _progressController.close();
  }
}

/// Internal download task representation
class _HLSDownloadTask {
  final String id;
  final String hlsManifestUrl;
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String destinationPath;
  final int? expectedDurationMs;
  final Function(double)? onProgress;
  final Completer<String?> completion = Completer<String?>();

  double _progress = 0.0;
  double get progress => _progress;

  _HLSDownloadTask({
    required this.id,
    required this.hlsManifestUrl,
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    required this.destinationPath,
    this.expectedDurationMs,
    this.onProgress,
  });

  void updateProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0);
    onProgress?.call(_progress);
  }

  void complete(String? path) {
    _progress = 1.0;
    completion.complete(path);
  }

  void fail(String error) {
    completion.completeError(Exception(error));
  }
}