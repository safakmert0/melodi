import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import 'artwork_embedding_service.dart';
import 'artwork_service.dart';
import 'database_service.dart';
import 'lyrics_embedding_service.dart';
import 'lyrics_service.dart';
import 'metadata_service.dart';
import 'parallel_downloader.dart';
import 'webview_stream_service.dart';
import 'storage_manager.dart';
import 'audio_quality_service.dart';
import 'explode_stream_service.dart';
import 'hls_stream_service.dart';
import 'sources/hifi_source.dart';
import 'ytmusic_service.dart';

enum DownloadState { pending, downloading, completed, failed }

class DownloadTask {
  final String id;
  final String spotifyTrackId;
  final String? sourceVideoId;
  // Bayat URL retry'de tazelenebilsin diye final değil.
  String? directUrl;
  // Hi-Fi (FLAC) olmazsa otomatik YouTube yedeği için video kimliği.
  final String? fallbackVideoId;
  final String title;
  final String artist;
  final String? album;
  final String? imageUrl;
  final int expectedDurationMs;
  DownloadState state;
  double progress;
  String? error;
  String? filePath;
  String requestedQuality;
  bool cancelled;

  DownloadTask({
    required this.id,
    required this.spotifyTrackId,
    this.sourceVideoId,
    this.directUrl,
    this.fallbackVideoId,
    required this.title,
    required this.artist,
    this.album,
    this.imageUrl,
    this.expectedDurationMs = 0,
    this.state = DownloadState.pending,
    this.progress = 0,
    this.error,
    this.filePath,
    this.requestedQuality = 'high',
    this.cancelled = false,
  });
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._();
  factory DownloadManager() => _instance;
  DownloadManager._() {
    _loadConfig();
    unawaited(_cleanupOrphanedParts());
  }

  final List<DownloadTask> _tasks = [];
  int _activeDownloads = 0;
  int _maxParallel = 2;
  bool _wifiOnly = false;
  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 3;
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();

  Future<void> _cleanupOrphanedParts() async {
    try {
      final dir = Directory(await StorageManager.instance.getStorageLocation());
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name =
            entity.path.split(Platform.pathSeparator).last.toLowerCase();
        // .part (paralel indirici) ve .tmp_ (explode/HLS önbelleği):
        // sahipsiz kalan yarımlar diski ve eşleşmeyi kirletmesin.
        if (!name.endsWith('.part') && !name.startsWith('.tmp_')) {
          continue;
        }
        final modified = await entity.lastModified();
        if (DateTime.now().difference(modified) > const Duration(hours: 1)) {
          // Tasks are process-local; an old partial surviving an app restart
          // has no owner and cannot be completed safely.
          await entity.delete();
        }
      }
    } catch (error) {
      debugPrint('Partial download cleanup failed: $error');
    }
  }

  Future<void> _loadConfig() async {
    try {
      final parallel =
          await DatabaseService.instance.getSetting('download_parallel');
      final wifi =
          await DatabaseService.instance.getSetting('download_wifi_only');
      _maxParallel = int.tryParse(parallel ?? '')?.clamp(1, 3) ?? 2;
      _wifiOnly = wifi == 'true';
    } catch (_) {}
  }

  Future<void> setWifiOnly(bool v) async {
    _wifiOnly = v;
    await DatabaseService.instance
        .setSetting('download_wifi_only', v.toString());
  }

  Future<void> setMaxParallel(int v) async {
    _maxParallel = v.clamp(1, 3);
    await DatabaseService.instance
        .setSetting('download_parallel', _maxParallel.toString());
    _processQueue();
  }

  bool get wifiOnly => _wifiOnly;
  int get maxParallel => _maxParallel;

  /// Callback when a download completes - triggers library refresh
  VoidCallback? onDownloadComplete;

  Stream<List<DownloadTask>> get taskStream => _controller.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  String _taskId() =>
      'dl_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';

  bool addTask({
    required String spotifyTrackId,
    required String title,
    required String artist,
    String? album,
    String? imageUrl,
    String? sourceVideoId,
    String? directUrl,
    String? fallbackVideoId,
    int expectedDurationMs = 0,
  }) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedArtist = artist.trim().toLowerCase();
    final alreadyQueued = _tasks.any((task) =>
        task.title.trim().toLowerCase() == normalizedTitle &&
        task.artist.trim().toLowerCase() == normalizedArtist &&
        task.state != DownloadState.failed);
    if (alreadyQueued) return false;

    final task = DownloadTask(
      id: _taskId(),
      spotifyTrackId: spotifyTrackId,
      sourceVideoId: sourceVideoId,
      directUrl: directUrl,
      fallbackVideoId: fallbackVideoId,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
      expectedDurationMs: expectedDurationMs,
    );
    _tasks.add(task);
    _processQueue();
    _notify();
    return true;
  }

  void addTasks(List<Map<String, String>> tracks) {
    for (final t in tracks) {
      addTask(
        spotifyTrackId: t['id']!,
        title: t['title']!,
        artist: t['artist']!,
        album: t['album'],
        imageUrl: t['imageUrl'],
        directUrl: t['directUrl'],
        expectedDurationMs: int.tryParse(t['durationMs'] ?? '') ?? 0,
      );
    }
  }

  bool isDurationCompatible(Duration candidate, int expectedMs) {
    if (expectedMs <= 0 || candidate.inMilliseconds <= 0) return true;
    final toleranceMs = (expectedMs * 0.15).round().clamp(20000, 60000);
    return (candidate.inMilliseconds - expectedMs).abs() <= toleranceMs;
  }

  /// Bozuk/kesik indirmeler için alt sınır. Hata sayfaları ve başlık-parçası
  /// dosyalar bunun altında kalır; gerçek ses dosyaları çok üstündedir.
  static const int _minAudioBytes = 32 * 1024;

  /// İndirilen dosyanın varlığını, boyutunu ve çözümlenebilir süresini
  /// doğrular. Bozuk dosya kütüphaneye girerse çalma patlar ve uygulama
  /// sessizce stream'e düşer; o yüzden import'tan ÖNCE çağrılır.
  Future<bool> _verifyDownloadedFile(
    String path,
    int expectedDurationMs,
  ) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      if (await file.length() < _minAudioBytes) {
        debugPrint('Download verification failed (too small): $path');
        return false;
      }
      final metadata = await MetadataService.extractMetadata(path)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      if (metadata == null) {
        debugPrint('Download verification failed (no metadata): $path');
        return false;
      }
      if (metadata.duration.inMilliseconds <= 0) {
        debugPrint('Download verification failed (zero duration): $path');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Download verification error: $e');
      return false;
    }
  }

  Future<void> _processQueue() async {
    // Wi-Fi only kontrolü — Evermusic/SpotiFLAC esintili
    if (_wifiOnly) {
      try {
        final conn = await Connectivity().checkConnectivity().timeout(
            const Duration(seconds: 5),
            onTimeout: () => [ConnectivityResult.wifi]);
        final isWifi = conn.contains(ConnectivityResult.wifi) ||
            conn.contains(ConnectivityResult.ethernet);
        final isMobile = conn.contains(ConnectivityResult.mobile);
        if (isMobile && !isWifi) {
          // Mobilde beklet, Wi-Fi gelince otomatik devam edecek (queue paused)
          return;
        }
      } catch (_) {}
    }
    while (_activeDownloads < _maxParallel) {
      final pending =
          _tasks.where((t) => t.state == DownloadState.pending).toList();
      if (pending.isEmpty) break;
      _activeDownloads++;
      _downloadTrack(pending.first);
    }
  }

  /// Ağ değişiminde kuyruğu uyandır (SpotiFLAC retryAfterReconnect)
  void onConnectivityChanged() => _processQueue();

  Future<void> _downloadTrack(DownloadTask task) async {
    task.state = DownloadState.downloading;
    _notify();
    try {
      final db = DatabaseService.instance;
      task.requestedQuality = await AudioQualityService().getDownloadQuality();
      final downloadDir =
          Directory(await StorageManager.instance.getStorageLocation());
      await downloadDir.create(recursive: true);

      task.progress = 0.05;
      task.error = 'Kaynaklar aranıyor...';
      _notify();

      final streamUrl = (task.directUrl != null && task.directUrl!.isNotEmpty)
          ? task.directUrl
          : null;
      final videoId = (task.sourceVideoId ?? '').trim();

      if (task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'İptal edildi';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.progress = 0.3;
      _notify();

      String? resultPath;
      if (streamUrl != null &&
          !_isHttpUrl(streamUrl) &&
          await File(streamUrl).exists()) {
        debugPrint('Download using local file: $streamUrl');
        resultPath = streamUrl;
      } else if (videoId.isNotEmpty) {
        // YouTube: InnerTube ile dogrudan indirme dizinine indir.
        task.progress = 0.15;
        task.error = 'YouTube indiriliyor...';
        _notify();
        resultPath = await _downloadViaBundle(task, downloadDir)
            .timeout(const Duration(minutes: 8), onTimeout: () => null);
        // Fallback: direkt URL uzerinden indirme (nadiren)
        if (resultPath == null && streamUrl != null && _isHttpUrl(streamUrl)) {
          resultPath = await _downloadFromUrl(streamUrl, task, downloadDir)
              .timeout(const Duration(minutes: 5), onTimeout: () => null);
        }
        if (resultPath == null) {
          final detail = ExplodeStreamService.instance.lastError;
          task.state = DownloadState.failed;
          task.error = (detail != null && detail.isNotEmpty)
              ? 'İndirme başarısız: $detail'
              : 'YouTube şu an giriş istiyor (bot koruması). Arama çalışır, indirme geçici kapalı.';
          _notify();
          _activeDownloads--;
          _processQueue();
          return;
        }
      } else if (streamUrl != null && _isHttpUrl(streamUrl)) {
        resultPath = await _downloadFromUrl(streamUrl, task, downloadDir)
            .timeout(const Duration(minutes: 5), onTimeout: () => null);
        // FLAC (kaliteli servis) telefona inmezse otomatik YouTube yedeği.
        final fallbackId = (task.fallbackVideoId ?? '').trim();
        if ((resultPath == null || resultPath.isEmpty) &&
            fallbackId.isNotEmpty &&
            !task.cancelled) {
          try {
            final base = await HiFiSource()
                .baseUrl()
                .timeout(const Duration(seconds: 10), onTimeout: () => '');
            if (base.isNotEmpty) {
              task.error = 'Alternatif kaynaktan indiriliyor...';
              _notify();
              resultPath = await _downloadFromUrl(
                '$base/api/stream/$fallbackId',
                task,
                downloadDir,
              ).timeout(const Duration(minutes: 5), onTimeout: () => null);
            }
          } catch (e) {
            debugPrint('Download fallback miss: $e');
          }
          if (task.cancelled) resultPath = null;
        }
      } else {
        task.state = DownloadState.failed;
        task.error = 'Eşleşen şarkı bulunamadı';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }



      // Bütünlük kapısı: bozuk/kesik dosya import'a ve veritabanına
      // girmeden elenir; resultPath null'lanınca aşağıdaki mevcut retry
      // mekanizması (exponential backoff) devreye girer.
      if (resultPath != null) {
        final intact = await _verifyDownloadedFile(
          resultPath,
          task.expectedDurationMs,
        );
        if (!intact) {
          try {
            await File(resultPath).delete();
          } catch (_) {}
          resultPath = null;
        }
      }

      if (resultPath == null || task.cancelled) {
        if (task.cancelled) {
          task.state = DownloadState.failed;
          task.error = 'İptal edildi';
          _notify();
          _activeDownloads--;
          _processQueue();
          return;
        }
        // SpotiFLAC-8Spine esintili: exponential backoff retry
        final retries = _retryCounts[task.id] ?? 0;
        if (retries < _maxRetries) {
          _retryCounts[task.id] = retries + 1;
          task.state = DownloadState.pending;
          task.error = 'Yeniden deneniyor (${retries + 1}/$_maxRetries)...';
          task.progress = 0;
          _notify();
          _activeDownloads--;
          Future.delayed(
              Duration(seconds: (1 << retries) * 2), () => _processQueue());
          return;
        }
        task.state = DownloadState.failed;
        task.error = 'İndirme başarısız';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.filePath = resultPath;
      task.progress = 0.8;
      _notify();

      if (!task.cancelled) {
        String? importedPath;
        try {
          importedPath = await _importDownloadedFile(resultPath, task)
              .timeout(const Duration(minutes: 2), onTimeout: () => null);
        } catch (_) {
          importedPath = null;
        }
        if (importedPath != null) {
          task.filePath = importedPath;
          task.state = DownloadState.completed;
          task.progress = 1.0;
          task.error = null;
          try {
            await db
                .upsertDownloadedTrack(task.spotifyTrackId, importedPath)
                .timeout(const Duration(seconds: 5));
          } catch (_) {}
          onDownloadComplete?.call();
        } else {
          final downloadedFile = File(resultPath);
          if (await downloadedFile.exists()) {
            task.filePath = resultPath;
            task.state = DownloadState.completed;
            task.progress = 1.0;
            task.error = null;
            try {
              await db
                  .upsertDownloadedTrack(task.spotifyTrackId, resultPath)
                  .timeout(const Duration(seconds: 5));
            } catch (_) {}
            onDownloadComplete?.call();
          } else {
            task.state = DownloadState.failed;
            task.error ??= 'İndirilen dosya bulunamadı';
          }
        }
      } else {
        task.state = DownloadState.failed;
        task.error = 'İptal edildi';
      }
    } catch (e) {
      final retries = _retryCounts[task.id] ?? 0;
      if (retries < _maxRetries && !task.cancelled) {
        _retryCounts[task.id] = retries + 1;
        task.state = DownloadState.pending;
        task.error = 'Yeniden deneniyor (${retries + 1}/$_maxRetries)...';
        task.progress = 0;
        _notify();
        _activeDownloads--;
        Future.delayed(
            Duration(seconds: (1 << retries) * 2), () => _processQueue());
        return;
      }
      task.state = DownloadState.failed;
      task.error = e.toString();
    }
    _retryCounts.remove(task.id);
    _notify();
    _activeDownloads--;
    _processQueue();
  }


  Future<String?> _downloadFromUrl(
      String url, DownloadTask task, Directory dir) async {
    // YouTube tek-baglanti kisitlamasini asmak icin paralel cok baglantili
    // indirme (her baglanti ayri kota alir). Non-http scheme fail fast.
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      debugPrint('Download from URL skipped non-http url: $url');
      return null;
    }
    try {
      final sanitized = task.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final safeTitle = sanitized.isEmpty ? 'download' : sanitized;

      // Önce HEAD ile uzantıyı tahmin et (ucuz, 6 sn cap).
      String ext = 'm4a';
      try {
        final headClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6);
        final headReq = await headClient.headUrl(Uri.parse(url));
        headReq.headers.set('User-Agent',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
        final headResp =
            await headReq.close().timeout(const Duration(seconds: 6));
        if (headResp.headers.contentType != null) {
          ext = _downloadExtension(url, headResp.headers.contentType);
        }
        headClient.close();
      } catch (_) {
        ext = _downloadExtension(url, null);
      }

      // Keep the name stable so retries target the same file.
      final stableId = task.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath = '${dir.path}/${safeTitle}_$stableId.$ext';

      final got = await ParallelDownloader.download(
        url: url,
        outputPath: filePath,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
        },
        connections: 6,
        onProgress: (received, total) {
          if (total != null && total > 0) {
            task.progress =
                (0.3 + (received / total) * 0.48).clamp(0.3, 0.78);
            task.error = 'İndiriliyor...';
            _notify();
          }
        },
        isCancelled: () => task.cancelled,
        timeout: const Duration(minutes: 5),
      ).timeout(const Duration(minutes: 5, seconds: 30),
          onTimeout: () => null);
      if (got == null) return null;
      final len = await File(got).length();
      if (len < 1000) {
        try {
          await File(got).delete();
        } catch (_) {}
        return null;
      }
      return got;
    } on TimeoutException catch (e) {
      debugPrint('Download from URL timeout: $e');
      return null;
    } catch (e) {
      debugPrint('Download from URL error: $e');
      return null;
    }
  }

  static bool _isHttpUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  /// YouTube parçasını explode hattıyla (cok istemci + imza cozme)
  /// doğrudan indirme dizinine indirir. Video kimliği `sourceVideoId` alanından alınır.
  ///
  /// Aktarim iOS URLSession arka plan indiricisiyle yapilir: uygulama
  /// arkaplana alininca da indirme surer. Cozumleme foreground'da olur.
  Future<String?> _downloadViaBundle(
      DownloadTask task, Directory downloadDir) async {
    final videoId = (task.sourceVideoId ?? '').trim();
    if (videoId.isEmpty) return null;
    try {
      // 0. Backend proxy (yt-dlp, Range): cihazda manifest/bot duvarına
      // takılsa bile sunucu üzerinden iner. Başarısız olursa sessizce
      // explode hattına düşer.
      try {
        final base = await HiFiSource()
            .baseUrl()
            .timeout(const Duration(seconds: 10), onTimeout: () => '');
        if (base.isNotEmpty && !task.cancelled) {
          task.progress = 0.12;
          task.error = 'Sunucu üzerinden indiriliyor...';
          _notify();
          final viaProxy = await _downloadFromUrl(
            '$base/api/stream/$videoId',
            task,
            downloadDir,
          ).timeout(const Duration(minutes: 5), onTimeout: () => null);
          if (viaProxy != null &&
              viaProxy.isNotEmpty &&
              await File(viaProxy).exists()) {
            task.progress = 0.75;
            _notify();
            return viaProxy;
          }
          if (task.cancelled) return null;
        }
      } catch (e) {
        debugPrint('Backend proxy download miss: $e');
      }
      final safeTitle =
          '${task.artist} - ${task.title}'.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final baseName =
          safeTitle.isEmpty ? videoId : '${safeTitle}_$videoId';
      final tmpPath = '${downloadDir.path}/.tmp_$baseName.bin';
      // 0a. Gizli tarayici cozumu (gercek oynatici baglami) + paralel
      // indirme. Bot duvarinda en saglam cihattir.
      try {
        if (!task.cancelled) {
          task.progress = 0.1;
          task.error = 'Kaynak çözümleniyor...';
          _notify();
          debugPrint('📥 DownloadManager: WebView resolving $videoId');
          final web = await WebViewStreamService.instance
              .resolveAudio(videoId)
              .timeout(const Duration(seconds: 40), onTimeout: () => null);
          final webUrl = web?['url']?.toString() ?? '';
          if (webUrl.startsWith('http') && !task.cancelled) {
            debugPrint('📥 DownloadManager: WebView URL OK, starting parallel download');
            final webPath = await ParallelDownloader.download(
              url: webUrl,
              outputPath: tmpPath,
              headers: Map<String, String>.from(
                  ExplodeStreamService.instance.streamHeaders),
              connections: 6,
              onProgress: (received, total) {
                if (total != null && total > 0) {
                  task.progress =
                      (0.1 + (received / total) * 0.62).clamp(0.1, 0.72);
                  task.error = 'YouTube indiriliyor...';
                  _notify();
                }
              },
              isCancelled: () => task.cancelled,
              timeout: const Duration(minutes: 5),
            ).timeout(const Duration(minutes: 5, seconds: 30),
                onTimeout: () => null);
            if (webPath != null && webPath.isNotEmpty) {
              debugPrint('📥 DownloadManager: WebView download SUCCESS');
              task.progress = 0.75;
              _notify();
              return webPath;
            }
            debugPrint('📥 DownloadManager: WebView download returned null');
            if (task.cancelled) return null;
          } else {
            debugPrint('📥 DownloadManager: WebView returned empty/invalid URL: $webUrl');
          }
        }
      } catch (e) {
        debugPrint('📥 DownloadManager WebView exception: $e');
      }
      // 0b. Hizli hat: el yapimi istemci (ANDROID 19.29.1) ile URL cozup
      // paralel indir. Kutuphane manifest'i bot duvarina takilsa bile
      // bu hat calisir; timeout'lari beklemez.
      try {
        if (!task.cancelled) {
          task.progress = 0.12;
          task.error = 'Kaynak çözümleniyor...';
          _notify();
          final fastUrl = await YtMusicService.instance
              .getStreamUrl(videoId)
              .timeout(const Duration(seconds: 25), onTimeout: () => null);
          if (fastUrl != null &&
              fastUrl.startsWith('http') &&
              !task.cancelled) {
            final fastPath = await ParallelDownloader.download(
              url: fastUrl,
              outputPath: tmpPath,
              headers: Map<String, String>.from(
                  ExplodeStreamService.instance.streamHeaders),
              connections: 6,
              onProgress: (received, total) {
                if (total != null && total > 0) {
                  task.progress =
                      (0.12 + (received / total) * 0.6).clamp(0.12, 0.72);
                  task.error = 'YouTube indiriliyor...';
                  _notify();
                }
              },
              isCancelled: () => task.cancelled,
              timeout: const Duration(minutes: 5),
            ).timeout(const Duration(minutes: 5, seconds: 30),
                onTimeout: () => null);
            if (fastPath != null && fastPath.isNotEmpty) {
              task.progress = 0.75;
              _notify();
              return fastPath;
            }
            if (task.cancelled) return null;
          }
        }
      } catch (e) {
        debugPrint('Fast innertube download miss: $e');
      }
      // 0. HLS hatti (en hizli): fMP4 segmentler paralel cekilir.
      task.progress = 0.1;
      task.error = 'Kaynak çözümleniyor...';
      _notify();
      try {
        final hlsUrl = await ExplodeStreamService.instance
            .getHlsUrl(videoId)
            .timeout(const Duration(seconds: 45), onTimeout: () => null);
        if (hlsUrl != null && !task.cancelled) {
          final hlsPath = await HlsStreamService.instance.downloadHlsToM4a(
            playlistUrl: hlsUrl,
            outputPath: tmpPath,
            headers:
                Map<String, String>.from(ExplodeStreamService.instance.streamHeaders),
            onProgress: (received, total) {
              if (total != null && total > 0) {
                task.progress =
                    (0.1 + (received / total) * 0.6).clamp(0.1, 0.7);
                task.error = 'YouTube indiriliyor...';
                _notify();
              }
            },
            isCancelled: () => task.cancelled,
            timeout: const Duration(minutes: 6),
          );
          if (hlsPath != null && hlsPath.isNotEmpty) {
            task.progress = 0.75;
            _notify();
            return hlsPath;
          }
          if (task.cancelled) return null;
        }
      } catch (_) {}
      // 1. Akışı çözümle (manifest; hızlı olmalı).
      task.progress = 0.15;
      task.error = 'Kaynak çözümleniyor...';
      _notify();
      final resolved = await ExplodeStreamService.instance
          .resolveStream(videoId)
          .timeout(const Duration(seconds: 45), onTimeout: () => null);
      if (resolved != null && !task.cancelled) {
        // HIZLI YOL ÖNCE: paralel foreground indirme (tek-baglanti
        // YouTube kisitlamasini asar; tipik parca 10-30 sn). Uygulama
        // arkaplandayken yarisirsa asagidaki bg yedegi devreye girer.
        task.progress = 0.2;
        task.error = 'YouTube indiriliyor...';
        _notify();
        final fastPath = await ParallelDownloader.download(
          url: resolved.url,
          outputPath:
              '${downloadDir.path}/.tmp_$baseName${resolved.ext}',
          headers: resolved.headers,
          connections: 6,
          onProgress: (received, total) {
            if (total != null && total > 0) {
              task.progress =
                  (0.2 + (received / total) * 0.55).clamp(0.2, 0.75);
              _notify();
            }
          },
          isCancelled: () => task.cancelled,
          timeout: const Duration(minutes: 5),
        ).timeout(const Duration(minutes: 5, seconds: 30),
            onTimeout: () => null);
        if (fastPath != null && fastPath.isNotEmpty) {
          task.progress = 0.75;
          _notify();
          return fastPath;
        }
        if (task.cancelled) return null;
        // YAVAS YOL (yedek): iOS URLSession arka plan transferi.
        task.error = 'Arka planda deneniyor...';
        _notify();
        final bgPath = await _backgroundFetch(
          task,
          url: resolved.url,
          headers: resolved.headers,
          filename: '.tmp_$baseName${resolved.ext}',
        );
        if (bgPath != null && bgPath.isNotEmpty) {
          task.progress = 0.75;
          _notify();
          return bgPath;
        }
        if (task.cancelled) return null;
      }
      task.progress = 0.2;
      task.error = 'YouTube indiriliyor...';
      _notify();
      final path = await ExplodeStreamService.instance.downloadToFile(
        videoId: videoId,
        outputPath: tmpPath,
        onProgress: (received, total) {
          if (total != null && total > 0) {
            task.progress = (0.2 + (received / total) * 0.55).clamp(0.2, 0.75);
            task.error = 'YouTube indiriliyor...';
            _notify();
          }
        },
        isCancelled: () => task.cancelled,
      ).timeout(const Duration(minutes: 10), onTimeout: () => null);
      if (path == null || path.isEmpty || !await File(path).exists()) {
        debugPrint('Explode download failed for $videoId, trying InnerTube');
        // Yedek hat: uygulamanın kendi müzik-istemcili InnerTube indiricisi.
        // Explode istemcileri LOGIN_REQUIRED döndüğünde bunlar çalışabilir.
        try {
          task.progress = 0.3;
          task.error = 'Alternatif kaynaktan indiriliyor...';
          _notify();
          final inner = await YtMusicService.instance.downloadToFile(
            trackId: videoId,
            title: task.title,
            artist: task.artist,
            outputPath: tmpPath,
          ).timeout(const Duration(minutes: 6), onTimeout: () => null);
          final innerPath = inner?['file_path']?.toString() ?? '';
          if (inner != null &&
              inner['success'] == true &&
              innerPath.isNotEmpty &&
              await File(innerPath).exists()) {
            task.progress = 0.75;
            _notify();
            return innerPath;
          }
        } catch (e) {
          debugPrint('InnerTube download fallback error: $e');
        }
        return null;
      }
      task.progress = 0.75;
      _notify();
      return path;
    } catch (e) {
      debugPrint('Explode download error: $e');
      return null;
    }
  }

  /// iOS URLSession arka plan transferi. Uygulama arkaplana alininca ya da
  /// ekran kilitlenince de indirme surer; bosta `null` doner (on plan yedek
  /// devreye girer). Iptalde yarim dosyayi temizler.
  Future<String?> _backgroundFetch(
    DownloadTask task, {
    required String url,
    required Map<String, String> headers,
    required String filename,
  }) async {
    try {
      final bgTask = bg.DownloadTask(
        url: url,
        filename: filename,
        headers: headers,
        baseDirectory: bg.BaseDirectory.applicationDocuments,
        directory: 'Melodi/Offline',
        retries: 2,
        metaData: task.id,
      );
      final result = await bg.FileDownloader()
          .download(
            bgTask,
            onProgress: (p) {
              task.progress =
                  (0.2 + p.clamp(0.0, 1.0) * 0.55).clamp(0.2, 0.75);
              _notify();
            },
          )
          .timeout(const Duration(minutes: 15),
              onTimeout: () => throw TimeoutException('arka plan indirme'));
      final path = await bgTask.filePath();
      if (task.cancelled) {
        try {
          if (path.isNotEmpty && await File(path).exists()) {
            await File(path).delete();
          }
        } catch (_) {}
        return null;
      }
      if (result.status != bg.TaskStatus.complete) {
        debugPrint('Background download status: ${result.status}');
        return null;
      }
      if (path.isEmpty || !await File(path).exists()) return null;
      if (await File(path).length() < 1000) {
        try {
          await File(path).delete();
        } catch (_) {}
        return null;
      }
      return path;
    } catch (e) {
      debugPrint('Background download error: $e');
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

  Future<String?> _importDownloadedFile(
      String filePath, DownloadTask task) async {
    try {
      final db = DatabaseService.instance;
      final musicDir =
          Directory(await StorageManager.instance.getStorageLocation());
      await musicDir.create(recursive: true);

      final ext = filePath.split('.').last;
      final isVideo = const {
        'mp4',
        'm4v',
        'mov',
        'webm',
        'avi',
        'mkv',
      }.contains(ext.toLowerCase());
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
      final metadata = await MetadataService.extractMetadata(filePath)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      await sourceFile.rename(destPath);
      // Rename sonrası hedef doğrulanır (taşıma yarım kalmış olabilir).
      final destFile = File(destPath);
      if (!await destFile.exists() ||
          await destFile.length() < _minAudioBytes) {
        debugPrint('Imported file missing or truncated: $destPath');
        return null;
      }

      // Hızlı kayıt: kapak/söz ağı beklenmeden kütüphane satırı yazılır,
      // indirme hemen tamamlanır. Zenginleştirme (kapak+söz bulma+gömme,
      // ~15-45sn) arka planda sürer, bitince aynı satırı günceller.
      task.progress = 0.86;
      task.error = 'Kütüphaneye ekleniyor...';
      _notify();
      final songId = await _insertImportedRow(
        db,
        destPath: destPath,
        task: task,
        metadata: metadata,
        isVideo: isVideo,
      );
      if (!isVideo) {
        unawaited(_enrichDownloadedFile(destPath, task, songId));
      }

      return destPath;
    } catch (e) {
      debugPrint('Import downloaded file error: $e');
      return null;
    }
  }

  /// İndirilen dosyanın kütüphane satırını ağ beklemeden yazar.
  /// Dönen kimlik, arka plandaki zenginleştirmenin güncelleyeceği satırdır.
  Future<String> _insertImportedRow(
    DatabaseService db, {
    required String destPath,
    required DownloadTask task,
    required SongModel? metadata,
    required bool isVideo,
  }) async {
    if (!isVideo &&
        metadata != null &&
        !isDurationCompatible(metadata.duration, task.expectedDurationMs)) {
      // Catalogue durations are frequently rounded or refer to a different
      // edition. A fully downloaded playable file must not be deleted after
      // spending minutes transferring it; retain it and expose it locally.
      debugPrint(
        'Downloaded duration differs from catalogue: '
        '${metadata.duration.inMilliseconds}/${task.expectedDurationMs}',
      );
    }

    if (metadata != null) {
      final placeholderId = task.spotifyTrackId.startsWith('spotify:')
          ? task.spotifyTrackId
          : 'spotify:${task.spotifyTrackId}';
      SongModel? placeholder = await db.getSongById(placeholderId);
      if (placeholder == null) {
        final titleKey = _matchKey(task.title);
        final artistKey = _matchKey(task.artist.split(',').first);
        for (final candidate in await db.getAllSongs()) {
          if (!candidate.filePath.startsWith('spotify://')) continue;
          final sameTitle = _matchKey(candidate.title) == titleKey;
          final candidateArtist =
              _matchKey(candidate.artist.split(',').first);
          final sameArtist = artistKey.isEmpty ||
              candidateArtist.contains(artistKey) ||
              artistKey.contains(candidateArtist);
          if (sameTitle && sameArtist) {
            placeholder = candidate;
            break;
          }
        }
      }
      final normalized = metadata.copyWith(
        id: placeholder?.id ?? metadata.id,
        title: task.title,
        artist: task.artist,
        album: (task.album?.isNotEmpty ?? false) ? task.album : metadata.album,
        filePath: destPath,
        albumArt: placeholder?.albumArt ?? metadata.albumArt,
        fileSize: await File(destPath).length(),
        lyrics: placeholder?.lyrics ?? metadata.lyrics,
      );
      await db.insertSong(normalized);
      return normalized.id;
    }

    // Metadata okunamadı diye indirme kaybolmasın: dosya boyut kapısından
    // geçti, kütüphaneye minimal satır yazılır. Yoksa dosya diskte durur
    // ama satır olmadığı için uygulama yine stream'e düşerdi.
    final fallbackId = task.spotifyTrackId.startsWith('spotify:')
        ? task.spotifyTrackId
        : 'spotify:${task.spotifyTrackId}';
    final minimal = SongModel(
      id: fallbackId,
      title: task.title,
      artist: task.artist,
      album:
          (task.album?.isNotEmpty ?? false) ? task.album! : 'Unknown Album',
      duration: Duration(milliseconds: task.expectedDurationMs),
      filePath: destPath,
      fileSize: await File(destPath).length(),
    );
    await db.insertSong(minimal);
    return minimal.id;
  }

  /// Kapak+söz bulma/gömme: indirme "tamamlandı" olduktan SONRA arka planda
  /// koşar. Bitince satır yerinde güncellenir; şarkı o arada silinmişse
  /// dokunulmaz (silineni diriltmez), yolu değişmişse atlanır.
  Future<void> _enrichDownloadedFile(
    String destPath,
    DownloadTask task,
    String songId,
  ) async {
    try {
      final db = DatabaseService.instance;
      // Kapak + söz araması paralel koşar.
      final artworkFuture = () async {
        if (task.imageUrl != null && task.imageUrl!.isNotEmpty) {
          try {
            final b = await _downloadImageBytes(task.imageUrl!)
                .timeout(const Duration(seconds: 10), onTimeout: () => null);
            if (b != null && b.isNotEmpty) return b;
          } catch (_) {}
        }
        try {
          return await ArtworkService.fetchArtwork(
            title: task.title,
            artist: task.artist,
            album: task.album ?? '',
            duration: Duration(milliseconds: task.expectedDurationMs),
          ).timeout(const Duration(seconds: 10), onTimeout: () => null);
        } catch (_) {
          return null;
        }
      }();
      final lyricsFuture = () async {
        try {
          return await LyricsService.fetchLyrics(
            artist: task.artist,
            track: task.title,
            album: task.album,
            durationMs: task.expectedDurationMs > 0
                ? task.expectedDurationMs
                : null,
            preferSynced: true,
          ).timeout(const Duration(seconds: 10), onTimeout: () => null);
        } catch (error) {
          debugPrint('Downloaded lyrics lookup failed: $error');
          return null;
        }
      }();
      final fetched = await Future.wait([artworkFuture, lyricsFuture]);
      final Uint8List? artworkBytes = fetched[0] as Uint8List?;
      final lyricsResult = fetched[1] as LyricsResult?;
      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        try {
          await ArtworkEmbeddingService.embedCoverArt(
            filePath: destPath,
            artwork: artworkBytes,
          ).timeout(const Duration(seconds: 15), onTimeout: () => false);
        } catch (e) {
          debugPrint('Artwork embedding failed: $e');
        }
      }

      final lyricsText = lyricsResult?.syncedLrc ?? lyricsResult?.plainText;
      if (lyricsText != null && lyricsText.isNotEmpty) {
        try {
          await LyricsEmbeddingService.embedAndNormalize(
            filePath: destPath,
            lyrics: lyricsText,
            expectedDurationMs: task.expectedDurationMs,
          ).timeout(const Duration(seconds: 10), onTimeout: () => false);
        } catch (_) {}
      }

      final current = await db.getSongById(songId);
      if (current == null || current.filePath != destPath) return;
      final updated = current.copyWith(
        albumArt: (artworkBytes != null && artworkBytes.isNotEmpty)
            ? artworkBytes
            : current.albumArt,
        lyrics: (lyricsText != null && lyricsText.isNotEmpty)
            ? lyricsText
            : current.lyrics,
      );
      await db.insertSong(updated);
    } catch (e) {
      debugPrint('Download enrich failed: $e');
    }
  }

  String _matchKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(HttpHeaders.userAgentHeader, 'Melodi/1.0');
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final bytes = await consolidateHttpClientResponseBytes(response);
        return bytes.length >= 1024 ? bytes : null;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  /// Registers a download that was performed externally (e.g. a podcast
  /// episode fetched by [PodcastService]) so it appears in the Downloads list
  /// and triggers a library refresh.
  void registerExternalDownload({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? imageUrl,
    required String filePath,
    int expectedDurationMs = 0,
  }) {
    _tasks.removeWhere((t) => t.id == id);
    _tasks.add(DownloadTask(
      id: id,
      spotifyTrackId: id,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
      expectedDurationMs: expectedDurationMs,
      state: DownloadState.completed,
      progress: 1.0,
      filePath: filePath,
    ));
    onDownloadComplete?.call();
    _notify();
  }

  void cancelTask(String taskId) {
    final tasks = _tasks.where((t) => t.id == taskId).toList();
    if (tasks.isNotEmpty) {
      tasks.first.cancelled = true;
      if (tasks.first.state == DownloadState.pending) {
        tasks.first.state = DownloadState.failed;
        tasks.first.error = 'Cancelled';
        _notify();
      }
    }
  }

  void cancelAll() {
    for (final task in _tasks) {
      task.cancelled = true;
      if (task.state == DownloadState.pending) {
        task.state = DownloadState.failed;
        task.error = 'Cancelled';
      }
    }
    _notify();
  }

  void retryTask(String taskId) {
    final task = _tasks
        .where((t) => t.id == taskId && t.state == DownloadState.failed)
        .toList();
    if (task.isNotEmpty) {
      task.first.state = DownloadState.pending;
      task.first.error = null;
      task.first.progress = 0;
      task.first.cancelled = false;
      _processQueue();
      _notify();
    }
  }

  void retryAllFailed() {
    for (final task in _tasks) {
      if (task.state == DownloadState.failed) {
        task.state = DownloadState.pending;
        task.error = null;
        task.progress = 0;
        task.cancelled = false;
      }
    }
    _processQueue();
    _notify();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.state == DownloadState.completed);
    _notify();
  }

  void clearFailed() {
    _tasks.removeWhere((t) => t.state == DownloadState.failed);
    _notify();
  }

  void clearTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    _tasks.removeWhere((task) =>
        ids.contains(task.id) &&
        (task.state == DownloadState.completed ||
            task.state == DownloadState.failed));
    _notify();
  }

  void _notify() {
    _controller.add(List.from(_tasks));
  }

  void dispose() {
    _controller.close();
  }
}
