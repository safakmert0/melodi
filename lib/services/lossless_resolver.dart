import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LosslessTrack {
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
  final String source;
  final String sourceId;
  final String? downloadUrl;
  final String format;

  const LosslessTrack({
    required this.title,
    required this.artist,
    this.album,
    required this.durationMs,
    required this.source,
    required this.sourceId,
    this.downloadUrl,
    this.format = 'FLAC',
  });
}

class SpotifyTrackDetail {
  final String id;
  final String isrc;
  final String name;
  final List<String> artists;
  final String? album;
  final int durationMs;

  const SpotifyTrackDetail({
    required this.id,
    required this.isrc,
    required this.name,
    required this.artists,
    this.album,
    required this.durationMs,
  });
}

class LosslessResolver {
  static const _deezerApi = 'https://api.deezer.com';

  static Future<SpotifyTrackDetail?> getSpotifyTrackDetail(
    String trackId,
    String accessToken,
  ) async {
    try {
      final url = 'https://api.spotify.com/v1/tracks/$trackId?market=US';
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('Authorization', 'Bearer $accessToken');
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final isrc = data['external_ids']?['isrc'] as String?;
        if (isrc == null) return null;
        return SpotifyTrackDetail(
          id: trackId,
          isrc: isrc,
          name: data['name'] as String? ?? '',
          artists: (data['artists'] as List?)
                  ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
                  .where((a) => a.isNotEmpty)
                  .toList() ?? [],
          album: (data['album'] as Map<String, dynamic>?)?['name'] as String?,
          durationMs: data['duration_ms'] as int? ?? 0,
        );
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('getSpotifyTrackDetail error: $e');
      return null;
    }
  }

  static Future<List<LosslessTrack>> searchDeezerByIsrc(String isrc) async {
    try {
      final uri = Uri.parse('$_deezerApi/search?q=isrc:$isrc');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) return [];
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final tracks = data['data'] as List?;
        if (tracks == null || tracks.isEmpty) return [];
        return tracks.map((t) {
          final track = t as Map<String, dynamic>;
          return LosslessTrack(
            title: track['title'] as String? ?? '',
            artist: (track['artist'] as Map<String, dynamic>?)?['name'] as String? ?? '',
            album: (track['album'] as Map<String, dynamic>?)?['title'] as String?,
            durationMs: (track['duration'] as int? ?? 0) * 1000,
            source: 'Deezer',
            sourceId: track['id'].toString(),
            format: 'FLAC',
          );
        }).toList();
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('searchDeezerByIsrc error: $e');
      return [];
    }
  }

  static Future<LosslessTrack?> resolve(SpotifyTrackDetail spotifyTrack) async {
    if (spotifyTrack.isrc.isEmpty) return null;
    final deezerResults = await searchDeezerByIsrc(spotifyTrack.isrc);
    if (deezerResults.isNotEmpty) return deezerResults.first;
    return null;
  }
}
