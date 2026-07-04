import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Custom audio source that streams YouTube audio via just_audio.
/// Based on the approach from Gyawun Music (sheikhhaziq/gyawun_music).
/// Handles YouTube's throttling, range requests, and rate limiting.
class YouTubeAudioSource extends StreamAudioSource {
  final String videoId;
  final String quality; // 'high' or 'low'
  final YoutubeExplode _yt;

  YouTubeAudioSource({
    required this.videoId,
    this.quality = 'high',
    super.tag,
  }) : _yt = YoutubeExplode();

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      // Use androidVr client - most reliable for audio streaming
      final manifest = await _yt.videos.streams.getManifest(
        videoId,
        requireWatchPage: true,
        ytClients: [YoutubeApiClient.androidVr],
      );

      final supportedStreams = manifest.audioOnly
          .where((s) => s.container == StreamContainer.mp4)
          .toList();

      if (supportedStreams.isEmpty) {
        // Fallback to any audio stream
        final anyAudio = manifest.audioOnly.toList();
        if (anyAudio.isEmpty) {
          throw Exception('No audio stream available for video $videoId');
        }
        return _buildResponse(anyAudio, start, end);
      }

      // Sort by bitrate and pick based on quality
      final sorted = supportedStreams.toList()
        ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));

      final audioStream = quality == 'high' ? sorted.last : sorted.first;
      return _buildResponse([audioStream], start, end);
    } catch (e) {
      debugPrint('YouTubeAudioSource request error: $e');
      rethrow;
    }
  }

  StreamAudioResponse _buildResponse(
    List<AudioOnlyStreamInfo> streams,
    int? start,
    int? end,
  ) {
    final streamInfo = streams.first;
    final totalBytes = streamInfo.size.totalBytes;

    start ??= 0;
    end ??= totalBytes;
    if (end > totalBytes) end = totalBytes;
    if (start >= totalBytes) start = totalBytes - 1;

    final stream = _yt.videos.streams.get(streamInfo, start, end);

    return StreamAudioResponse(
      sourceLength: totalBytes,
      contentLength: end - start,
      offset: start,
      stream: stream,
      contentType: streamInfo.codec.mimeType,
    );
  }

  void dispose() {
    _yt.close();
  }
}
