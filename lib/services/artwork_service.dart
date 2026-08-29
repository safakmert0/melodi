import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// LA Player tarzı sade kapak bulma: önce yerel etiket, yoksa iTunes'da ilk sonuç.
/// Puanlama/threshold yok, ilk artworkUrl100 → 600x600.
class ArtworkService {
  static const _itunesSearchUrl = 'https://itunes.apple.com/search';

  static Future<Uint8List?> fetchArtwork({
    required String title,
    required String artist,
    required String album,
    Duration duration = Duration.zero,
  }) async {
    if (!canSearch(title: title, artist: artist, album: album)) return null;

    HttpClient? client;
    try {
      final terms = [
        title,
        if (_isReliable(artist)) artist,
        if (_isReliable(album)) album,
      ];
      final uri = Uri.parse(_itunesSearchUrl).replace(
        queryParameters: {
          'term': terms.join(' '),
          'media': 'music',
          'entity': 'song',
          'limit': '5',
          'country': 'TR',
        },
      );
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      for (final raw in results) {
        if (raw is! Map<String, dynamic>) continue;
        final artUrl = raw['artworkUrl100'] as String?;
        if (artUrl == null || artUrl.isEmpty) continue;
        final largeUrl = artUrl
            .replaceAll('100x100bb', '600x600bb')
            .replaceAll('100x100', '600x600');
        final bytes = await _downloadImage(largeUrl);
        if (bytes != null) return bytes;
      }
      return null;
    } catch (error) {
      debugPrint('Artwork fetch error: $error');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  @visibleForTesting
  static bool canSearch({
    required String title,
    required String artist,
    required String album,
  }) {
    if (!_isReliable(title)) return false;
    return _isReliable(artist) || _isReliable(album);
  }

  @visibleForTesting
  static bool isConfidentMatch({
    required String title,
    required String artist,
    required String album,
    Duration duration = Duration.zero,
    required String candidateTitle,
    required String candidateArtist,
    required String candidateAlbum,
    Duration candidateDuration = Duration.zero,
  }) {
    if (!canSearch(title: title, artist: artist, album: album)) return false;

    final titleSimilarity =
        _similarity(_cleanTitle(title), _cleanTitle(candidateTitle));
    if (titleSimilarity < 0.72) return false;

    if (_isReliable(artist)) {
      if (_similarity(_clean(artist), _clean(candidateArtist)) < 0.68) {
        return false;
      }
    } else if (_similarity(_clean(album), _clean(candidateAlbum)) < 0.72) {
      return false;
    }

    if (duration > Duration.zero && candidateDuration > Duration.zero) {
      final difference =
          (duration.inMilliseconds - candidateDuration.inMilliseconds).abs();
      final tolerance = max(30000, (duration.inMilliseconds * 0.25).round());
      if (difference > tolerance) return false;
    }
    return true;
  }

  static int _scoreCandidate({
    required String title,
    required String artist,
    required String album,
    required Duration duration,
    required String candidateTitle,
    required String candidateArtist,
    required String candidateAlbum,
    required Duration candidateDuration,
  }) {
    if (!isConfidentMatch(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      candidateTitle: candidateTitle,
      candidateArtist: candidateArtist,
      candidateAlbum: candidateAlbum,
      candidateDuration: candidateDuration,
    )) {
      return -1;
    }

    final titleScore =
        _similarity(_cleanTitle(title), _cleanTitle(candidateTitle));
    final artistScore = _similarity(_clean(artist), _clean(candidateArtist));
    final albumScore = _similarity(_clean(album), _clean(candidateAlbum));
    var score = (titleScore * 55).round();
    if (_isReliable(artist)) score += (artistScore * 30).round();
    if (_isReliable(album)) score += (albumScore * 10).round();
    if (duration > Duration.zero && candidateDuration > Duration.zero) {
      score += 10;
    }
    return score;
  }

  static String _cleanTitle(String value) {
    return _clean(value.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ').replaceAll(
        RegExp(r'\b(feat|ft|official|video|audio|lyrics?)\b.*',
            caseSensitive: false),
        ' '));
  }

  static double _similarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    final compactLeft = left.replaceAll(' ', '');
    final compactRight = right.replaceAll(' ', '');
    final shorter = min(compactLeft.length, compactRight.length);
    final longer = max(compactLeft.length, compactRight.length);
    if (shorter >= 4 &&
        (compactLeft.contains(compactRight) ||
            compactRight.contains(compactLeft))) {
      return shorter / longer;
    }
    final leftTokens =
        left.split(' ').where((token) => token.isNotEmpty).toSet();
    final rightTokens =
        right.split(' ').where((token) => token.isNotEmpty).toSet();
    final union = leftTokens.union(rightTokens).length;
    if (union == 0) return 0;
    return leftTokens.intersection(rightTokens).length / union;
  }

  static bool _isReliable(String value) {
    final normalized = _clean(value).replaceAll(' ', '');
    if (normalized.length < 2) return false;
    const placeholders = {
      'unknown',
      'unknownartist',
      'unknownalbum',
      'bilinmeyen',
      'bilinmeyensanatci',
      'bilinmeyenalbum',
      'sanatciyok',
      'albumyok',
      'untitled',
    };
    return !placeholders.contains(normalized);
  }

  static String _clean(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static Future<Uint8List?> _downloadImage(String url) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      );
      final result = bytes.takeBytes();
      return result.length >= 1024 ? result : null;
    } catch (error) {
      debugPrint('Image download error: $error');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
