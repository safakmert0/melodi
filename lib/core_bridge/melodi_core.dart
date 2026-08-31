import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

export 'melodi_core.g.dart';

class MelodiCore {
  MelodiCore._();

  static const MethodChannel _channel = MethodChannel('melodi/core');

  static bool _initialized = false;
  static String? _version;
  static String? _apiVersion;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final result = await _channel.invokeMethod('initialize', {
        'apiVersion': '1',
      });

      _version = result['version'] as String?;
      _apiVersion = result['apiVersion'] as String?;
      _initialized = true;

      debugPrint('MelodiCore initialized: version=$_version, apiVersion=$_apiVersion');
    } on PlatformException catch (e) {
      debugPrint('Failed to initialize MelodiCore: ${e.message}');
      rethrow;
    }
  }

  static bool get isInitialized => _initialized;
  static String? get version => _version;
  static String? get apiVersion => _apiVersion;

  static Future<String> ping() async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('ping');
    return result as String;
  }

  static Future<SearchResponse> search(SearchRequest request) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('search', request.toJson());
    return SearchResponse.fromJson(result);
  }

  static Future<MatchResponse> match(MatchRequest request) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('match', request.toJson());
    return MatchResponse.fromJson(result);
  }

  static Future<ResolveResponse> resolve(ResolveRequest request) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('resolve', request.toJson());
    return ResolveResponse.fromJson(result);
  }

  static Future<DownloadResponse> download(DownloadRequest request) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('download', request.toJson());
    return DownloadResponse.fromJson(result);
  }

  static Future<void> cancelDownload(String jobId) async {
    _ensureInitialized();
    await _channel.invokeMethod('cancelDownload', {'jobId': jobId});
  }

  static Future<JobStatus?> getDownloadStatus(String jobId) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('getDownloadStatus', {'jobId': jobId});
    if (result == null) return null;
    return JobStatus.fromJson(result);
  }

  static Future<List<JobStatus>> listDownloads() async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('listDownloads');
    final list = result as List;
    return list.map((e) => JobStatus.fromJson(e)).toList();
  }

  static Stream<JobStatus> downloadProgress(String jobId) {
    _ensureInitialized();
    final controller = StreamController<JobStatus>.broadcast();

    void handler(dynamic event) {
      if (event is Map && event['jobId'] == jobId) {
        controller.add(JobStatus.fromJson(event));
      }
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'downloadProgress') {
        handler(call.arguments);
      }
    });

    controller.onCancel = () {
      _channel.setMethodCallHandler(null);
    };

    return controller.stream;
  }

  static Future<ExtensionResponse> installExtension(InstallExtensionRequest request) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('installExtension', request.toJson());
    return ExtensionResponse.fromJson(result);
  }

  static Future<void> uninstallExtension(String id) async {
    _ensureInitialized();
    await _channel.invokeMethod('uninstallExtension', {'id': id});
  }

  static Future<void> enableExtension(String id, bool enabled) async {
    _ensureInitialized();
    await _channel.invokeMethod('enableExtension', {'id': id, 'enabled': enabled});
  }

  static Future<List<ExtensionInfo>> listExtensions() async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('listExtensions');
    final list = result as List;
    return list.map((e) => ExtensionInfo.fromJson(e)).toList();
  }

  static Future<ExtensionInfo?> getExtension(String id) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('getExtension', {'id': id});
    if (result == null) return null;
    return ExtensionInfo.fromJson(result);
  }

  static Future<String> checkExtensionHealth(String id) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('checkExtensionHealth', {'id': id});
    return result as String;
  }

  static Future<ExtensionResponse> updateExtension(String id) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('updateExtension', {'id': id});
    return ExtensionResponse.fromJson(result);
  }

  static Future<List<ExtensionResponse>> updateAllExtensions() async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('updateAllExtensions');
    final list = result as List;
    return list.map((e) => ExtensionResponse.fromJson(e)).toList();
  }

  static Future<void> addRepository(String url) async {
    _ensureInitialized();
    await _channel.invokeMethod('addRepository', {'url': url});
  }

  static Future<void> removeRepository(String url) async {
    _ensureInitialized();
    await _channel.invokeMethod('removeRepository', {'url': url});
  }

  static Future<List<RepositoryInfo>> listRepositories() async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('listRepositories');
    final list = result as List;
    return list.map((e) => RepositoryInfo.fromJson(e)).toList();
  }

  static Future<MetadataResponse> readMetadata(String filePath) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('readMetadata', {'filePath': filePath});
    return MetadataResponse.fromJson(result);
  }

  static Future<void> writeMetadata(String filePath, Map<String, String> tags) async {
    _ensureInitialized();
    await _channel.invokeMethod('writeMetadata', {'filePath': filePath, 'tags': tags});
  }

  static Future<void> embedCoverArt(String filePath, List<int> imageData, String mimeType) async {
    _ensureInitialized();
    await _channel.invokeMethod('embedCoverArt', {
      'filePath': filePath,
      'imageData': imageData,
      'mimeType': mimeType,
    });
  }

  static Future<void> embedLyrics(String filePath, String lyrics) async {
    _ensureInitialized();
    await _channel.invokeMethod('embedLyrics', {'filePath': filePath, 'lyrics': lyrics});
  }

  static Future<String> extractLyrics(String filePath) async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('extractLyrics', {'filePath': filePath});
    return result as String;
  }

  static Future<Stats> getStats() async {
    _ensureInitialized();
    final result = await _channel.invokeMethod('getStats');
    return Stats.fromJson(result);
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('MelodiCore not initialized. Call initialize() first.');
    }
  }

  static void dispose() {
    _initialized = false;
    _version = null;
    _apiVersion = null;
  }
}

class SearchRequest {
  final String query;
  final int limit;
  final int offset;
  final List<String> sources;
  final List<String> excludeSources;

  SearchRequest({
    required this.query,
    this.limit = 20,
    this.offset = 0,
    this.sources = const [],
    this.excludeSources = const [],
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'limit': limit,
    'offset': offset,
    'sources': sources,
    'excludeSources': excludeSources,
  };
}

class SearchResponse {
  final List<SearchResult> results;
  final int total;
  final int tookMs;

  SearchResponse({
    required this.results,
    required this.total,
    required this.tookMs,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      results: (json['results'] as List? ?? [])
          .map((e) => SearchResult.fromJson(e))
          .toList(),
      total: json['total'] as int? ?? 0,
      tookMs: json['tookMs'] as int? ?? 0,
    );
  }
}

class SearchResult {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String source;
  final String? thumbnail;
  final String? quality;
  final double? score;
  final Map<String, String>? extras;

  SearchResult({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    required this.source,
    this.thumbnail,
    this.quality,
    this.score,
    this.extras,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      durationMs: json['durationMs'] as int?,
      source: json['source'] as String,
      thumbnail: json['thumbnail'] as String?,
      quality: json['quality'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      extras: (json['extras'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)),
    );
  }
}

class MatchRequest {
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? isrc;

  MatchRequest({
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.isrc,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'isrc': isrc,
  };
}

class MatchResponse {
  final MatchResult? match;
  final List<MatchCandidate> candidates;

  MatchResponse({this.match, this.candidates = const []});

  factory MatchResponse.fromJson(Map<String, dynamic> json) {
    return MatchResponse(
      match: json['match'] != null ? MatchResult.fromJson(json['match']) : null,
      candidates: (json['candidates'] as List? ?? [])
          .map((e) => MatchCandidate.fromJson(e))
          .toList(),
    );
  }
}

class MatchResult {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? isrc;
  final double confidence;
  final ScoreBreakdown scoreBreakdown;
  final List<String> matchReasons;

  MatchResult({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.isrc,
    required this.confidence,
    required this.scoreBreakdown,
    required this.matchReasons,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      durationMs: json['durationMs'] as int?,
      isrc: json['isrc'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      scoreBreakdown: ScoreBreakdown.fromJson(json['scoreBreakdown']),
      matchReasons: (json['matchReasons'] as List? ?? []).cast<String>(),
    );
  }
}

class ScoreBreakdown {
  final double titleScore;
  final double artistScore;
  final double albumScore;
  final double durationScore;
  final double isrcScore;
  final double totalScore;

  ScoreBreakdown({
    required this.titleScore,
    required this.artistScore,
    required this.albumScore,
    required this.durationScore,
    required this.isrcScore,
    required this.totalScore,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      titleScore: (json['titleScore'] as num).toDouble(),
      artistScore: (json['artistScore'] as num).toDouble(),
      albumScore: (json['albumScore'] as num).toDouble(),
      durationScore: (json['durationScore'] as num).toDouble(),
      isrcScore: (json['isrcScore'] as num).toDouble(),
      totalScore: (json['totalScore'] as num).toDouble(),
    );
  }
}

class MatchCandidate {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String source;
  final double score;

  MatchCandidate({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    required this.source,
    required this.score,
  });

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    return MatchCandidate(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      durationMs: json['durationMs'] as int?,
      source: json['source'] as String,
      score: (json['score'] as num).toDouble(),
    );
  }
}

class ResolveRequest {
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? isrc;
  final String? quality;
  final List<String> providers;
  final List<String> exclude;
  final bool requireIsrc;

  ResolveRequest({
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.isrc,
    this.quality,
    this.providers = const [],
    this.exclude = const [],
    this.requireIsrc = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'isrc': isrc,
    'quality': quality,
    'providers': providers,
    'exclude': exclude,
    'requireIsrc': requireIsrc,
  };
}

class ResolveResponse {
  final AudioSource source;
  final MatchResult? match;
  final List<SearchResult> candidates;
  final String provider;
  final DateTime resolvedAt;

  ResolveResponse({
    required this.source,
    this.match,
    this.candidates = const [],
    required this.provider,
    required this.resolvedAt,
  });

  factory ResolveResponse.fromJson(Map<String, dynamic> json) {
    return ResolveResponse(
      source: AudioSource.fromJson(json['source']),
      match: json['match'] != null ? MatchResult.fromJson(json['match']) : null,
      candidates: (json['candidates'] as List? ?? [])
          .map((e) => SearchResult.fromJson(e))
          .toList(),
      provider: json['provider'] as String,
      resolvedAt: DateTime.parse(json['resolvedAt'] as String),
    );
  }
}

class AudioSource {
  final String url;
  final String mimeType;
  final int? bitrate;
  final String quality;
  final String provider;
  final String trackId;
  final Map<String, String>? headers;
  final int? expiresAt;
  final String? checksum;
  final int? size;

  AudioSource({
    required this.url,
    required this.mimeType,
    this.bitrate,
    required this.quality,
    required this.provider,
    required this.trackId,
    this.headers,
    this.expiresAt,
    this.checksum,
    this.size,
  });

  factory AudioSource.fromJson(Map<String, dynamic> json) {
    return AudioSource(
      url: json['url'] as String,
      mimeType: json['mimeType'] as String,
      bitrate: json['bitrate'] as int?,
      quality: json['quality'] as String,
      provider: json['provider'] as String,
      trackId: json['trackId'] as String,
      headers: (json['headers'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)),
      expiresAt: json['expiresAt'] as int?,
      checksum: json['checksum'] as String?,
      size: json['size'] as int?,
    );
  }
}

class DownloadRequest {
  final String url;
  final String title;
  final String artist;
  final String? album;
  final String? coverUrl;
  final String? quality;
  final int? expectedSize;
  final String? expectedChecksum;

  DownloadRequest({
    required this.url,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    this.quality,
    this.expectedSize,
    this.expectedChecksum,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'artist': artist,
    'album': album,
    'coverUrl': coverUrl,
    'quality': quality,
    'expectedSize': expectedSize,
    'expectedChecksum': expectedChecksum,
  };
}

class DownloadResponse {
  final String jobId;

  DownloadResponse({required this.jobId});

  factory DownloadResponse.fromJson(Map<String, dynamic> json) {
    return DownloadResponse(jobId: json['jobId'] as String);
  }
}

class JobStatus {
  final String jobId;
  final String state;
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final int speed;
  final String? error;
  final String? outputPath;

  JobStatus({
    required this.jobId,
    required this.state,
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.speed,
    this.error,
    this.outputPath,
  });

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      jobId: json['jobId'] as String,
      state: json['state'] as String,
      progress: (json['progress'] as num).toDouble(),
      bytesDownloaded: json['bytesDownloaded'] as int,
      totalBytes: json['totalBytes'] as int,
      speed: json['speed'] as int,
      error: json['error'] as String?,
      outputPath: json['outputPath'] as String?,
    );
  }

  bool get isCompleted => state == 'completed';
  bool get isFailed => state == 'failed';
  bool get isCancelled => state == 'cancelled';
  bool get isActive => state == 'downloading';
}

class ExtensionInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String kind;
  final bool enabled;
  final List<String> capabilities;
  final DateTime installedAt;
  final String health;

  ExtensionInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.kind,
    required this.enabled,
    required this.capabilities,
    required this.installedAt,
    required this.health,
  });

  factory ExtensionInfo.fromJson(Map<String, dynamic> json) {
    return ExtensionInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      author: json['author'] as String,
      kind: json['kind'] as String,
      enabled: json['enabled'] as bool,
      capabilities: (json['capabilities'] as List? ?? []).cast<String>(),
      installedAt: DateTime.parse(json['installedAt'] as String),
      health: json['health'] as String,
    );
  }
}

class InstallExtensionRequest {
  final String? packageUrl;
  final String? packagePath;
  final String? expectedSha256;
  final bool force;

  InstallExtensionRequest({
    this.packageUrl,
    this.packagePath,
    this.expectedSha256,
    this.force = false,
  });

  Map<String, dynamic> toJson() => {
    'packageUrl': packageUrl,
    'packagePath': packagePath,
    'expectedSha256': expectedSha256,
    'force': force,
  };
}

class ExtensionResponse {
  final ExtensionInfo? extension;
  final String? error;

  ExtensionResponse({this.extension, this.error});

  factory ExtensionResponse.fromJson(Map<String, dynamic> json) {
    return ExtensionResponse(
      extension: json['extension'] != null ? ExtensionInfo.fromJson(json['extension']) : null,
      error: json['error'] as String?,
    );
  }
}

class RepositoryInfo {
  final String url;
  final String name;
  final bool enabled;
  final DateTime? lastFetched;
  final String? error;

  RepositoryInfo({
    required this.url,
    required this.name,
    required this.enabled,
    this.lastFetched,
    this.error,
  });

  factory RepositoryInfo.fromJson(Map<String, dynamic> json) {
    return RepositoryInfo(
      url: json['url'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool,
      lastFetched: json['lastFetched'] != null ? DateTime.parse(json['lastFetched'] as String) : null,
      error: json['error'] as String?,
    );
  }
}

class MetadataRequest {
  final String filePath;

  MetadataRequest({required this.filePath});

  Map<String, dynamic> toJson() => {'filePath': filePath};
}

class MetadataResponse {
  final String format;
  final String filePath;
  final int fileSize;
  final Map<String, String> tags;
  final TechnicalInfo technical;

  MetadataResponse({
    required this.format,
    required this.filePath,
    required this.fileSize,
    required this.tags,
    required this.technical,
  });

  factory MetadataResponse.fromJson(Map<String, dynamic> json) {
    return MetadataResponse(
      format: json['format'] as String,
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      tags: (json['tags'] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as String)),
      technical: TechnicalInfo.fromJson(json['technical']),
    );
  }
}

class TechnicalInfo {
  final int sampleRate;
  final int bitDepth;
  final int channels;
  final int bitrate;
  final String codec;
  final int durationMs;

  TechnicalInfo({
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
    required this.bitrate,
    required this.codec,
    required this.durationMs,
  });

  factory TechnicalInfo.fromJson(Map<String, dynamic> json) {
    return TechnicalInfo(
      sampleRate: json['sampleRate'] as int,
      bitDepth: json['bitDepth'] as int,
      channels: json['channels'] as int,
      bitrate: json['bitrate'] as int,
      codec: json['codec'] as String,
      durationMs: json['durationMs'] as int,
    );
  }
}

class WriteMetadataRequest {
  final String filePath;
  final Map<String, String> tags;

  WriteMetadataRequest({required this.filePath, required this.tags});

  Map<String, dynamic> toJson() => {'filePath': filePath, 'tags': tags};
}

class CoverArtRequest {
  final String filePath;
  final List<int> imageData;
  final String mimeType;

  CoverArtRequest({required this.filePath, required this.imageData, required this.mimeType});

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'imageData': imageData,
    'mimeType': mimeType,
  };
}

class LyricsRequest {
  final String filePath;
  final String lyrics;

  LyricsRequest({required this.filePath, required this.lyrics});

  Map<String, dynamic> toJson() => {'filePath': filePath, 'lyrics': lyrics};
}

class Stats {
  final String version;
  final String apiVersion;
  final int uptimeMs;
  final bool initialized;

  Stats({
    required this.version,
    required this.apiVersion,
    required this.uptimeMs,
    required this.initialized,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      version: json['version'] as String,
      apiVersion: json['apiVersion'] as String,
      uptimeMs: json['uptimeMs'] as int,
      initialized: json['initialized'] as bool,
    );
  }
}