import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'metadata_service.dart';
import '../models/song_model.dart';

enum DuplicateType { exact, nearExact, differentQuality, differentFormat, differentSource }

class DuplicateGroup {
  final String id;
  final List<DuplicateTrack> tracks;
  final DuplicateType type;
  final double confidence;
  final String suggestedAction;

  const DuplicateGroup({
    required this.id,
    required this.tracks,
    required this.type,
    required this.confidence,
    required this.suggestedAction,
  });

  DuplicateTrack get bestTrack => tracks.reduce((a, b) =>
      a.qualityScore > b.qualityScore ? a : b);

  List<DuplicateTrack> get tracksToRemove => tracks.where((t) => t != bestTrack).toList();
}

class DuplicateTrack {
  final String songId;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String filePath;
  final int fileSize;
  final int bitrate;
  final String format;
  final int sampleRate;
  final int channels;
  final String? acoustId;
  final double qualityScore;

  const DuplicateTrack({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
    required this.fileSize,
    required this.bitrate,
    required this.format,
    required this.sampleRate,
    required this.channels,
    this.acoustId,
    required this.qualityScore,
  });
}

class LibraryHealthReport {
  final int totalTracks;
  final int localTracks;
  final int streamingTracks;
  final int duplicateGroups;
  final int duplicateTracks;
  final int missingMetadata;
  final int lowQualityTracks;
  final int corruptedFiles;
  final int orphanedFiles;
  final Map<String, int> formatDistribution;
  final Map<String, int> bitrateDistribution;
  final Map<String, int> genreDistribution;
  final DateTime generatedAt;

  const LibraryHealthReport({
    required this.totalTracks,
    required this.localTracks,
    required this.streamingTracks,
    required this.duplicateGroups,
    required this.duplicateTracks,
    required this.missingMetadata,
    required this.lowQualityTracks,
    required this.corruptedFiles,
    required this.orphanedFiles,
    required this.formatDistribution,
    required this.bitrateDistribution,
    required this.genreDistribution,
    required this.generatedAt,
  });
}

class LibraryHealthService {
  LibraryHealthService._();
  static final LibraryHealthService _instance = LibraryHealthService._();
  factory LibraryHealthService() => _instance;
  static LibraryHealthService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;

  Future<LibraryHealthReport> generateFullReport() async {
    final songs = await _db.getAllSongs();

    int duplicateGroups = 0;
    int duplicateTracks = 0;
    int missingMetadata = 0;
    int lowQualityTracks = 0;
    int corruptedFiles = 0;
    int orphanedFiles = 0;
    final formatDistribution = <String, int>{};
    final bitrateDistribution = <String, int>{};
    final genreDistribution = <String, int>{};

    final localSongs = songs.where((s) => s.filePath.isNotEmpty && !s.filePath.startsWith('spotify://')).toList();
    final streamingSongs = songs.where((s) => s.filePath.startsWith('spotify://') || s.filePath.isEmpty).toList();

    for (final song in localSongs) {
      if (song.title.isEmpty || song.artist.isEmpty) missingMetadata++;
      if (song.bitrate != null && song.bitrate! < 128000) lowQualityTracks++;

      final format = song.filePath.split('.').last.toLowerCase();
      formatDistribution[format] = (formatDistribution[format] ?? 0) + 1;

      if (song.bitrate != null) {
        final bucket = _bitrateBucket(song.bitrate!);
        bitrateDistribution[bucket] = (bitrateDistribution[bucket] ?? 0) + 1;
      }

      if (song.genre?.isNotEmpty == true) {
        genreDistribution[song.genre!] = (genreDistribution[song.genre!] ?? 0) + 1;
      }

      final file = File(song.filePath);
      if (!await file.exists()) {
        corruptedFiles++;
      } else if (await file.length() == 0) {
        corruptedFiles++;
      }
    }

    final duplicateResult = await findDuplicates(localSongs);
    duplicateGroups = duplicateResult.length;
    duplicateTracks = duplicateResult.expand((g) => g.tracksToRemove).length;

    for (final file in await _getOrphanedFiles()) {
      if (await file.exists()) orphanedFiles++;
    }

    return LibraryHealthReport(
      totalTracks: songs.length,
      localTracks: localSongs.length,
      streamingTracks: streamingSongs.length,
      duplicateGroups: duplicateGroups,
      duplicateTracks: duplicateTracks,
      missingMetadata: missingMetadata,
      lowQualityTracks: lowQualityTracks,
      corruptedFiles: corruptedFiles,
      orphanedFiles: orphanedFiles,
      formatDistribution: formatDistribution,
      bitrateDistribution: bitrateDistribution,
      genreDistribution: genreDistribution,
      generatedAt: DateTime.now(),
    );
  }

  Future<List<DuplicateGroup>> findDuplicates(List<SongModel> songs) async {
    final groups = <DuplicateGroup>[];
    final processed = <String>{};

    for (var i = 0; i < songs.length; i++) {
      final songA = songs[i];
      if (processed.contains(songA.id)) continue;

      final duplicates = <DuplicateTrack>[];
      final trackA = await _createDuplicateTrack(songA);
      if (trackA == null) continue;

      for (var j = i + 1; j < songs.length; j++) {
        final songB = songs[j];
        if (processed.contains(songB.id)) continue;

        final trackB = await _createDuplicateTrack(songB);
        if (trackB == null) continue;

        final match = _compareTracks(trackA, trackB);
        if (match != null) {
          duplicates.add(trackB);
          processed.add(songB.id);
        }
      }

      if (duplicates.isNotEmpty) {
        duplicates.insert(0, trackA);
        groups.add(DuplicateGroup(
          id: 'dup_${groups.length}',
          tracks: duplicates,
          type: _determineDuplicateType(duplicates),
          confidence: _calculateConfidence(duplicates),
          suggestedAction: _suggestAction(duplicates),
        ));
      }

      processed.add(songA.id);
    }

    return groups;
  }

  Future<DuplicateTrack?> _createDuplicateTrack(SongModel song) async {
    if (song.filePath.isEmpty || song.filePath.startsWith('spotify://')) return null;

    final file = File(song.filePath);
    if (!await file.exists()) return null;

    final metadata = await MetadataService.extractMetadata(song.filePath);
    if (metadata == null) return null;

    final qualityScore = await _calculateQualityScore(metadata, file);

    return DuplicateTrack(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: metadata.duration,
      filePath: song.filePath,
      fileSize: await file.length(),
      bitrate: metadata.bitrate ?? 0,
      format: song.filePath.split('.').last,
      sampleRate: metadata.sampleRate ?? 0,
      channels: 2,
      acoustId: null,
      qualityScore: qualityScore,
    );
  }

  DuplicateType? _compareTracks(DuplicateTrack a, DuplicateTrack b) {
    if (a.title.toLowerCase() == b.title.toLowerCase() &&
        a.artist.toLowerCase() == b.artist.toLowerCase()) {
      if ((a.duration.inMilliseconds - b.duration.inMilliseconds).abs() < 2000) {
        if (a.format == b.format) {
          if (a.bitrate == b.bitrate) return DuplicateType.exact;
          return DuplicateType.differentQuality;
        }
        return DuplicateType.differentFormat;
      }
      return DuplicateType.nearExact;
    }
    return null;
  }

  DuplicateType _determineDuplicateType(List<DuplicateTrack> tracks) {
    final formats = tracks.map((t) => t.format).toSet();
    final bitrates = tracks.map((t) => t.bitrate).toSet();
    final durations = tracks.map((t) => t.duration.inMilliseconds).toSet();

    if (formats.length == 1 && bitrates.length == 1 && durations.length == 1) {
      return DuplicateType.exact;
    }
    if (formats.length == 1 && bitrates.length > 1) {
      return DuplicateType.differentQuality;
    }
    if (formats.length > 1) {
      return DuplicateType.differentFormat;
    }
    return DuplicateType.nearExact;
  }

  double _calculateConfidence(List<DuplicateTrack> tracks) {
    if (tracks.length < 2) return 0.0;

    var score = 0.0;
    final base = tracks.first;

    for (var i = 1; i < tracks.length; i++) {
      final t = tracks[i];
      if (t.title == base.title && t.artist == base.artist) score += 0.4;
      if ((t.duration.inMilliseconds - base.duration.inMilliseconds).abs() < 2000) score += 0.3;
      if (t.album == base.album) score += 0.2;
      if (t.acoustId != null && t.acoustId == base.acoustId) score += 0.5;
    }

    return (score / (tracks.length - 1)).clamp(0.0, 1.0);
  }

  String _suggestAction(List<DuplicateTrack> tracks) {
    final best = tracks.reduce((a, b) => a.qualityScore > b.qualityScore ? a : b);
    final removeCount = tracks.length - 1;
    return 'Keep "${best.title}" (${best.format}, ${best.bitrate}kbps), remove $removeCount duplicate(s)';
  }

  Future<double> _calculateQualityScore(SongModel metadata, File file) async {
    double score = 0.0;
    score += (metadata.bitrate ?? 128000) / 320000 * 40;
    score += (metadata.sampleRate ?? 44100) / 48000 * 20;
    score += 15;
    final fmt = file.path.split('.').last.toLowerCase();
    score += fmt == 'flac' ? 25 : (fmt == 'm4a' ? 20 : 10);
    score -= (await file.length() == 0) ? 100 : 0;
    return score.clamp(0.0, 100.0);
  }

  String _bitrateBucket(int bitrate) {
    if (bitrate < 96000) return '< 96kbps';
    if (bitrate < 128000) return '96-128kbps';
    if (bitrate < 192000) return '128-192kbps';
    if (bitrate < 256000) return '192-256kbps';
    if (bitrate < 320000) return '256-320kbps';
    return '> 320kbps';
  }

  Future<List<File>> _getOrphanedFiles() async {
    final musicDir = Directory(await _db.getSetting('music_directory') ?? '');
    if (!await musicDir.exists()) return [];

    final songs = await _db.getAllSongs();
    final knownFiles = songs
        .where((s) => s.filePath.isNotEmpty && !s.filePath.startsWith('spotify://'))
        .map((s) => File(s.filePath).absolute.path)
        .toSet();

    final orphaned = <File>[];
    await for (final entity in musicDir.list(recursive: true)) {
      if (entity is File && _isAudioFile(entity.path)) {
        if (!knownFiles.contains(entity.absolute.path)) {
          orphaned.add(entity);
        }
      }
    }

    return orphaned;
  }

  bool _isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return {'mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'wav'}.contains(ext);
  }

  Future<void> removeDuplicates(List<DuplicateGroup> groups, {bool dryRun = true}) async {
    for (final group in groups) {
      for (final track in group.tracksToRemove) {
        if (!dryRun) {
          final file = File(track.filePath);
          if (await file.exists()) {
            await file.delete();
          }
          await _db.deleteSong(track.songId);
        }
        debugPrint('${dryRun ? '[DRY RUN] ' : ''}Removed: ${track.title} - ${track.artist}');
      }
    }
  }

  Future<void> fixMissingMetadata() async {
    final songs = await _db.getAllSongs();
    for (final song in songs) {
      if (song.filePath.isEmpty || song.filePath.startsWith('spotify://')) continue;
      if (song.title.isNotEmpty && song.artist.isNotEmpty) continue;

      final metadata = await MetadataService.extractMetadata(song.filePath);
      if (metadata != null) {
        final updated = song.copyWith(
          title: metadata.title ?? song.title,
          artist: metadata.artist ?? song.artist,
          album: metadata.album ?? song.album,
          genre: metadata.genre ?? song.genre,
          year: metadata.year ?? song.year,
          trackNumber: metadata.trackNumber ?? song.trackNumber,
        );
        await _db.insertSong(updated);
      }
    }
  }

  Future<void> convertLowQualityToOpus({int targetBitrate = 256000}) async {
    // FFmpeg conversion would go here
    debugPrint('Convert low quality tracks to Opus $targetBitrate bps - not implemented yet');
  }

  void dispose() {}
}