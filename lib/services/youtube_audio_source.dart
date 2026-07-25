// just_audio currently marks the range-stream API as experimental. This file
// isolates that dependency behind Melodi's stable SongModel/player contracts.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// The half-open byte range requested by just_audio: [start, endExclusive).
@immutable
class AudioByteRange {
  const AudioByteRange._(this.start, this.endExclusive);

  final int start;
  final int endExclusive;

  int get length => endExclusive - start;
  String get httpHeader => 'bytes=$start-${endExclusive - 1}';

  static AudioByteRange normalize({
    required int totalBytes,
    int? start,
    int? endExclusive,
  }) {
    if (totalBytes <= 0) {
      throw ArgumentError.value(totalBytes, 'totalBytes', 'must be positive');
    }
    final normalizedStart = (start ?? 0).clamp(0, totalBytes - 1);
    final normalizedEnd =
        (endExclusive ?? totalBytes).clamp(normalizedStart + 1, totalBytes);
    return AudioByteRange._(normalizedStart, normalizedEnd);
  }
}

/// Streams YouTube audio to just_audio while honoring iOS byte-range reads.
///
/// AVPlayer frequently asks for a range starting in the middle of a file. The
/// response must contain exactly that range; returning the full stream while
/// claiming a non-zero offset causes the decoder to stop before playback.
class YouTubeAudioSource extends StreamAudioSource {
  YouTubeAudioSource({
    required this.videoId,
    this.quality = 'high',
    super.tag,
  });

  final String videoId;
  final String quality; // 'high' or 'low'

  AudioOnlyStreamInfo? _cachedStream;
  DateTime? _cachedAt;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      var streamInfo = await _resolveStream();
      var range = AudioByteRange.normalize(
        totalBytes: streamInfo.size.totalBytes,
        start: start,
        endExclusive: end,
      );

      var opened = await _open(streamInfo, range);
      if (opened.response.statusCode == HttpStatus.forbidden ||
          opened.response.statusCode == HttpStatus.unauthorized) {
        await opened.response.drain<void>();
        opened.client.close(force: true);
        _cachedStream = null;
        _cachedAt = null;
        streamInfo = await _resolveStream(forceRefresh: true);
        range = AudioByteRange.normalize(
          totalBytes: streamInfo.size.totalBytes,
          start: start,
          endExclusive: end,
        );
        opened = await _open(streamInfo, range);
      }

      final response = opened.response;
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        final status = response.statusCode;
        await response.drain<void>();
        opened.client.close(force: true);
        throw HttpException('YouTube stream returned HTTP $status');
      }

      final skipBytes = response.statusCode == HttpStatus.ok ? range.start : 0;
      final body = _sliceAndClose(
        response,
        opened.client,
        skipBytes: skipBytes,
        takeBytes: range.length,
      );

      return StreamAudioResponse(
        sourceLength: streamInfo.size.totalBytes,
        contentLength: range.length,
        offset: range.start,
        stream: body,
        contentType:
            response.headers.contentType?.mimeType ?? streamInfo.codec.mimeType,
      );
    } catch (error, stackTrace) {
      debugPrint('YouTubeAudioSource request error: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<AudioOnlyStreamInfo> _resolveStream(
      {bool forceRefresh = false}) async {
    final cached = _cachedStream;
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 10)) {
      return cached;
    }

    final youtube = YoutubeExplode();
    try {
      final manifest = await youtube.videos.streams.getManifest(
        videoId,
        requireWatchPage: true,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.safari,
        ],
      );
      final mp4 = manifest.audioOnly
          .where((stream) => stream.container == StreamContainer.mp4)
          .toList();
      final candidates = mp4.isNotEmpty ? mp4 : manifest.audioOnly.toList();
      if (candidates.isEmpty) {
        throw StateError('No audio stream available for video $videoId');
      }
      candidates.sort(
          (a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
      final selected = quality == 'high' ? candidates.last : candidates.first;
      _cachedStream = selected;
      _cachedAt = DateTime.now();
      return selected;
    } finally {
      youtube.close();
    }
  }

  Future<({HttpClient client, HttpClientResponse response})> _open(
    AudioOnlyStreamInfo streamInfo,
    AudioByteRange range,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(streamInfo.url);
      request.headers.set(HttpHeaders.rangeHeader, range.httpHeader);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 Mobile/15E148',
      );
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      return (client: client, response: response);
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  static Stream<List<int>> _sliceAndClose(
    Stream<List<int>> source,
    HttpClient client, {
    required int skipBytes,
    required int takeBytes,
  }) async* {
    var skip = skipBytes;
    var remaining = takeBytes;
    try {
      await for (final chunk in source) {
        if (remaining <= 0) break;
        final from = math.min(skip, chunk.length);
        skip -= from;
        if (from == chunk.length) continue;
        final count = math.min(chunk.length - from, remaining);
        yield chunk.sublist(from, from + count);
        remaining -= count;
      }
    } finally {
      client.close(force: true);
    }
  }
}
