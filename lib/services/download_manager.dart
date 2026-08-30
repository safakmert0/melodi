import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import 'artwork_embedding_service.dart';
import 'artwork_service.dart';
import 'backend_api_service.dart';
import 'database_service.dart';
import 'lyrics_embedding_service.dart';
import 'lyrics_service.dart';
import 'metadata_service.dart';
import 'multi_source_search.dart';
import 'music_source.dart';
import 'piped_service.dart';
import 'storage_manager.dart';
import 'audio_quality_service.dart';
import 'track_matcher.dart';
import 'youtube_downloader.dart';

enum DownloadState { pending, downloading, completed, failed }

class DownloadTask {
  final String id;
  final String spotifyTrackId;
  final String? sourceVideoId;
  final String? directUrl;
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
  }

  final List<DownloadTask> _tasks = [];
  int _activeDownloads = 0;
  int _maxParallel = 1;
  bool _wifiOnly = false;
  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 3;
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();
  final YouTubeDownloader _youtubeDownloader = YouTubeDownloader();
  final MultiSourceSearch _multiSource = MultiSourceSearch();

  Future<void> _loadConfig() async {
    try {
      final parallel = await DatabaseService.instance.getSetting('download_parallel');
      final wifi = await DatabaseService.instance.getSetting('download_wifi_only');
      _maxParallel = int.tryParse(parallel ?? '')?.clamp(1, 3) ?? 1;
      _wifiOnly = wifi == 'true';
    } catch (_) {}
  }

  Future<void> setWifiOnly(bool v) async {
    _wifiOnly = v;
    await DatabaseService.instance.setSetting('download_wifi_only', v.toString());
  }

  Future<void> setMaxParallel(int v) async {
    _maxParallel = v.clamp(1, 3);
    await DatabaseService.instance.setSetting('download_parallel', _maxParallel.toString());
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

  List<OnlineTrack> _rankOnlineTracks(
      Iterable<OnlineTrack> tracks, DownloadTask task) {
    final candidates = tracks
        .where((track) =>
            isDurationCompatible(track.duration, task.expectedDurationMs))
        .toList();
    candidates.sort((a, b) {
      final aScore = TrackMatcher.scoreWithDuration(
        task.title,
        task.artist,
        task.expectedDurationMs,
        a.title,
        a.artist,
        a.duration.inMilliseconds,
      );
      final bScore = TrackMatcher.scoreWithDuration(
        task.title,
        task.artist,
        task.expectedDurationMs,
        b.title,
        b.artist,
        b.duration.inMilliseconds,
      );
      return bScore.compareTo(aScore);
    });
    return candidates;
  }

  Future<void> _processQueue() async {
    // Wi-Fi only kontrolü — Evermusic/SpotiFLAC esintili
    if (_wifiOnly) {
      try {
        final conn = await Connectivity().checkConnectivity();
        final isWifi = conn.contains(ConnectivityResult.wifi) || conn.contains(ConnectivityResult.ethernet);
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

      final query = '${task.artist} - ${task.title}';
      String? streamUrl = task.directUrl;
      List<OnlineTrack> allTracks = const [];

      if (streamUrl == null || streamUrl.isEmpty) {
        allTracks = await _multiSource.searchAllSync(query, limitPerSource: 3);
      }
      if (allTracks.isNotEmpty) {
        final priorityOrder = [
          MusicSourceType.navidrome,
          MusicSourceType.jiosaavn,
        ];
        for (final sourceType in priorityOrder) {
          final sourceTracks = _rankOnlineTracks(
            allTracks.where((track) => track.source == sourceType),
            task,
          );
          if (sourceTracks.isEmpty) continue;
          for (final track in sourceTracks.take(2)) {
            if (task.cancelled) break;
            try {
              task.progress = 0.1;
              task.error = '${track.sourceLabel} deneniyor...';
              _notify();
              final url = await _multiSource.getStreamUrl(track);
              if (url != null && url.isNotEmpty) {
                streamUrl = url;
                break;
              }
            } catch (_) {}
          }
          if (streamUrl != null) break;
        }
      }

      if (streamUrl == null && !task.cancelled) {
        final ytTracks = _rankOnlineTracks(
          allTracks.where((track) => track.source == MusicSourceType.youtube),
          task,
        );
        String? videoId = task.sourceVideoId;
        if (videoId == null && ytTracks.isNotEmpty) {
          videoId = ytTracks.first.id;
        } else if (videoId == null) {
          task.progress = 0.1;
          task.error = 'YouTube aranıyor...';
          _notify();
          final searchResults = await _multiSource.searchAllSync(
            query,
            limitPerSource: 5,
          );
          var ytResults = searchResults
              .where((t) => t.source == MusicSourceType.youtube)
              .toList();
          if (ytResults.isEmpty && task.title.trim().isNotEmpty) {
            // "Artist - Title" returned nothing; retry with the title alone so
            // common tagging mismatches still resolve to a playable track.
            final titleOnly = await _multiSource.searchAllSync(
              task.title.trim(),
              limitPerSource: 5,
            );
            ytResults = titleOnly
                .where((t) => t.source == MusicSourceType.youtube)
                .toList();
          }
          if (ytResults.isNotEmpty) {
            videoId = ytResults.first.id;
          }
        }

        if (videoId != null) {
          final String vid = videoId;
          final asVideo =
              (await DatabaseService.instance.getSetting('download_as_video')) ==
                  'true';

          Future<String?> _fetch(bool video) {
            if (video) {
              return _youtubeDownloader.downloadVideoTrack(
                vid,
                task.title,
                task.artist ?? '',
                downloadDir,
              );
            }
            return _youtubeDownloader.downloadFullTrack(
              vid,
              task.title,
              downloadDir,
              quality: task.requestedQuality ?? 'high',
            );
          }

          final attempts = asVideo ? [true, false] : [false];
          String? resultPath;
          for (final video in attempts) {
            if (task.cancelled) break;
            task.progress = 0.15;
            task.error = video
                ? 'YouTube video indiriliyor...'
                : 'YouTube indiriliyor (Backend/Piped)...';
            _notify();
            resultPath = await _fetch(video);
            if (resultPath != null) break;
          }

          if (resultPath != null) {
            task.filePath = resultPath;
            task.progress = 0.8;
            _notify();

            if (!task.cancelled) {
              final importedPath =
                  await _importDownloadedFile(resultPath, task);
              if (importedPath != null) {
                task.filePath = importedPath;
                task.state = DownloadState.completed;
                task.progress = 1.0;
                task.error = null;
                await db.upsertDownloadedTrack(
                    task.spotifyTrackId, importedPath);
                onDownloadComplete?.call();
              } else {
                final downloadedFile = File(resultPath);
                if (await downloadedFile.exists()) {
                  task.filePath = resultPath;
                  task.state = DownloadState.completed;
                  task.progress = 1.0;
                  task.error = null;
                  await db.upsertDownloadedTrack(
                      task.spotifyTrackId, resultPath);
                  onDownloadComplete?.call();
                } else {
                  task.state = DownloadState.failed;
                  task.error ??= 'İndirilen dosya bulunamadı';
                }
              }
            }
            _notify();
            _activeDownloads--;
            _processQueue();
            return;
          }
        }
      }

      if (streamUrl == null || task.cancelled) {
        task.state = DownloadState.failed;
        task.error = 'Eşleşen şarkı bulunamadı';
        _notify();
        _activeDownloads--;
        _processQueue();
        return;
      }

      task.progress = 0.3;
      _notify();

      var resultPath =
          await _downloadFromUrl(streamUrl, task.title, downloadDir);

      if (resultPath == null && !task.cancelled) {
        resultPath = await _downloadFromYouTube(
          task: task,
          searchResults: allTracks,
          query: query,
        );
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
          Future.delayed(Duration(seconds: (1 << retries) * 2), () => _processQueue());
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
        final importedPath = await _importDownloadedFile(resultPath, task);
        if (importedPath != null) {
          task.filePath = importedPath;
          task.state = DownloadState.completed;
          task.progress = 1.0;
          task.error = null;
          await db.upsertDownloadedTrack(task.spotifyTrackId, importedPath);
          onDownloadComplete?.call();
        } else {
          final downloadedFile = File(resultPath);
          if (await downloadedFile.exists()) {
            task.filePath = resultPath;
            task.state = DownloadState.completed;
            task.progress = 1.0;
            task.error = null;
            await db.upsertDownloadedTrack(task.spotifyTrackId, resultPath);
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
        Future.delayed(Duration(seconds: (1 << retries) * 2), () => _processQueue());
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

  Future<String?> _downloadFromYouTube({
    required DownloadTask task,
    required List<OnlineTrack> searchResults,
    required String query,
  }) async {
    try {
      final ytTracks = _rankOnlineTracks(
        searchResults.where((track) => track.source == MusicSourceType.youtube),
        task,
      );
      String? videoId = task.sourceVideoId;
      videoId ??= ytTracks.isEmpty ? null : ytTracks.first.id;
      if (videoId == null) {
        task.progress = 0.15;
        task.error = 'YouTube yedek kaynağı aranıyor...';
        _notify();
        final searchResults = await _multiSource.searchAllSync(
          query,
          limitPerSource: 5,
        );
        final ytResults = searchResults
            .where((t) => t.source == MusicSourceType.youtube)
            .toList();
        if (ytResults.isNotEmpty) {
          videoId = ytResults.first.id;
        }
      }
      if (videoId == null || task.cancelled) return null;
      task.progress = 0.2;
      task.error = 'YouTube yedek kaynağından indiriliyor...';
      _notify();
      return await _youtubeDownloader.downloadFullTrack(
        videoId,
        task.title,
        Directory(await StorageManager.instance.getStorageLocation()),
        quality: task.requestedQuality,
      );
    } catch (error) {
      debugPrint('YouTube fallback download error: $error');
      return null;
    }
  }

  Future<String?> _downloadFromUrl(
      String url, String title, Directory dir) async {
    // JollyTone/Evermusic/SpotiFLAC esintili: Range resume + background-friendly
    File? partFile;
    HttpClient? client;
    try {
      final sanitized = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      String safeTitle = sanitized.isEmpty ? 'download' : sanitized;

      // Önce HEAD ile uzantıyı tahmin et (contentType için), sonra resume
      String ext = 'm4a';
      try {
        final headClient = HttpClient()..connectionTimeout = const Duration(seconds: 10);
        final headReq = await headClient.headUrl(Uri.parse(url));
        headReq.headers.set('User-Agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
        final headResp = await headReq.close().timeout(const Duration(seconds: 10));
        if (headResp.headers.contentType != null) ext = _downloadExtension(url, headResp.headers.contentType);
        headClient.close();
      } catch (_) {
        ext = _downloadExtension(url, null);
      }

      final filePath = '${dir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final partPath = '$filePath.part';
      partFile = File(partPath);
      int existing = 0;
      if (await partFile.exists()) existing = await partFile.length();

      client = HttpClient()
        ..userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'
        ..connectionTimeout = const Duration(seconds: 120);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
      if (existing > 1024) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 206) {
        if (existing > 0 && response.statusCode == 416) {
          // Range not satisfiable, restart
          await partFile.delete();
          return await _downloadFromUrl(url, title, dir);
        }
        return null;
      }
      // 206 ise append, 200 ise overwrite
      final sink = partFile.openWrite(mode: existing > 0 && response.statusCode == 206 ? FileMode.append : FileMode.write);
      await response.pipe(sink);
      await sink.close();
      final len = await partFile.length();
      if (len < 1000) {
        await partFile.delete();
        return null;
      }
      await partFile.rename(filePath);
      return filePath;
    } catch (e) {
      debugPrint('Download from URL error: $e');
      return null;
    } finally {
      client?.close(force: true);
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
      var metadata = await MetadataService.extractMetadata(filePath);
      await sourceFile.rename(destPath);

      // ── Kapak resmi gömme (önceden atlanıyordu) ──
      Uint8List? artworkBytes;
      if (!isVideo) {
        task.progress = 0.83;
        task.error = 'Kapak resmi ekleniyor...';
        _notify();
        if (task.imageUrl != null && task.imageUrl!.isNotEmpty) {
          artworkBytes = await _downloadImageBytes(task.imageUrl!);
        }
        if (artworkBytes == null || artworkBytes.isEmpty) {
          try {
            artworkBytes = await ArtworkService.fetchArtwork(
              title: task.title,
              artist: task.artist,
              album: task.album ?? '',
              duration: metadata?.duration ?? Duration.zero,
            );
          } catch (_) {}
        }
        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          try {
            final ok = await ArtworkEmbeddingService.embedCoverArt(
              filePath: destPath,
              artwork: artworkBytes,
            );
            if (ok) {
              try {
                metadata = await MetadataService.extractMetadata(destPath) ?? metadata;
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('Artwork embedding failed: $e');
          }
        }
      }

      task.progress = 0.86;
      task.error = 'Senkronize sözler ekleniyor...';
      _notify();

      LyricsResult? lyricsResult;
      try {
        lyricsResult = await LyricsService.fetchLyrics(
          artist: task.artist,
          track: task.title,
          album: task.album,
          durationMs: task.expectedDurationMs > 0
              ? task.expectedDurationMs
              : metadata?.duration.inMilliseconds,
          preferSynced: true,
        );
      } catch (error) {
        debugPrint('Downloaded lyrics lookup failed: $error');
      }
      final lyricsText = lyricsResult?.syncedLrc ?? lyricsResult?.plainText;

      if (!isVideo) {
        final processed = await LyricsEmbeddingService.embedAndNormalize(
          filePath: destPath,
          lyrics: lyricsText,
          expectedDurationMs: task.expectedDurationMs,
        );
        if (processed) {
          metadata =
              await MetadataService.extractMetadata(destPath) ?? metadata;
        }
      }

      if (!isVideo &&
          metadata != null &&
          !isDurationCompatible(metadata.duration, task.expectedDurationMs)) {
        task.error =
            'Kaynak süresi parça süresiyle uyuşmuyor; farklı kaynak deneyin';
        final invalidFile = File(destPath);
        if (await invalidFile.exists()) await invalidFile.delete();
        return null;
      }

      if (metadata != null) {
        final placeholderId = task.spotifyTrackId.startsWith('navidrome:')
            ? task.spotifyTrackId
            : task.spotifyTrackId.startsWith('spotify:')
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
          id: placeholder?.id ??
              (task.spotifyTrackId.startsWith('navidrome:')
                  ? task.spotifyTrackId
                  : metadata.id),
          title: task.title,
          artist: task.artist,
          album:
              (task.album?.isNotEmpty ?? false) ? task.album : metadata.album,
          filePath: destPath,
          albumArt: (artworkBytes != null && artworkBytes.isNotEmpty)
              ? artworkBytes
              : (placeholder?.albumArt ?? metadata.albumArt),
          fileSize: await File(destPath).length(),
          lyrics: lyricsText ?? placeholder?.lyrics ?? metadata.lyrics,
        );
        await db.insertSong(normalized);
      }

      return destPath;
    } catch (e) {
      debugPrint('Import downloaded file error: $e');
      return null;
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
    _multiSource.dispose();
  }
}