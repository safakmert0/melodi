import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'music_source.dart';
import 'secure_storage_service.dart';

class NavidromeCredentials {
  const NavidromeCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;
}

class NavidromePlaylist {
  const NavidromePlaylist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.duration,
    this.coverArt,
    this.comment,
  });

  final String id;
  final String name;
  final int songCount;
  final Duration duration;
  final String? coverArt;
  final String? comment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songCount': songCount,
        'duration': duration.inSeconds,
        'coverArt': coverArt,
        'comment': comment,
      };
}

/// Client for the open Subsonic API implemented by Navidrome and compatible
/// personal music servers. Credentials never leave secure storage; requests
/// use Subsonic's salted token instead of sending the password in the URL.
class NavidromeService {
  NavidromeService._();

  static final NavidromeService instance = NavidromeService._();

  static const _serverKey = 'navidrome_server_url';
  static const _usernameKey = 'navidrome_username';
  static const _passwordKey = 'navidrome_password';
  static const _apiVersion = '1.16.1';

  final SecureStorageService _storage = SecureStorageService.instance;
  NavidromeCredentials? _credentials;

  NavidromeCredentials? get credentials => _credentials;
  bool get isConnected => _credentials != null;

  static String normalizeServerUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/rest')) {
      normalized = normalized.substring(0, normalized.length - 5);
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Güvenli sunucu adresi https:// ile başlamalı',
      );
    }
    return normalized;
  }

  Future<NavidromeCredentials?> loadConfiguration() async {
    final server = await _storage.read(_serverKey);
    final username = await _storage.read(_usernameKey);
    final password = await _storage.read(_passwordKey);
    if (server == null ||
        server.isEmpty ||
        username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      _credentials = null;
      return null;
    }
    try {
      _credentials = NavidromeCredentials(
        serverUrl: normalizeServerUrl(server),
        username: username,
        password: password,
      );
    } on FormatException {
      _credentials = null;
    }
    return _credentials;
  }

  Future<bool> isConfigured() async {
    await loadConfiguration();
    return isConnected;
  }

  Future<String?> getBaseUrl() async {
    await loadConfiguration();
    return _credentials?.serverUrl;
  }

  Future<void> connect({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final candidate = NavidromeCredentials(
      serverUrl: normalizeServerUrl(serverUrl),
      username: username.trim(),
      password: password,
    );
    if (candidate.username.isEmpty || candidate.password.isEmpty) {
      throw const FormatException('Kullanıcı adı ve parola gerekli');
    }
    await _request('ping', credentials: candidate);
    await _storage.write(_serverKey, candidate.serverUrl);
    await _storage.write(_usernameKey, candidate.username);
    await _storage.write(_passwordKey, candidate.password);
    _credentials = candidate;
  }

  Future<void> disconnect() async {
    await _storage.delete(_serverKey);
    await _storage.delete(_usernameKey);
    await _storage.delete(_passwordKey);
    _credentials = null;
  }

  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];
    final response = await _request('search3', parameters: {
      'query': query.trim(),
      'songCount': '$limit',
      'albumCount': '0',
      'artistCount': '0',
    });
    final result = response['searchResult3'] as Map<String, dynamic>?;
    return _parseSongs(result?['song']);
  }

  Future<List<NavidromePlaylist>> getPlaylists() async {
    final response = await _request('getPlaylists');
    final container = response['playlists'] as Map<String, dynamic>?;
    final raw = container?['playlist'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return NavidromePlaylist(
            id: map['id']?.toString() ?? '',
            name: map['name']?.toString() ?? 'Adsız liste',
            songCount: _asInt(map['songCount']),
            duration: Duration(seconds: _asInt(map['duration'])),
            coverArt: map['coverArt']?.toString(),
            comment: map['comment']?.toString(),
          );
        })
        .where((playlist) => playlist.id.isNotEmpty)
        .toList();
  }

  Future<List<OnlineTrack>> getPlaylistTracks(String playlistId) async {
    final response = await _request(
      'getPlaylist',
      parameters: {'id': playlistId},
    );
    final playlist = response['playlist'] as Map<String, dynamic>?;
    return _parseSongs(playlist?['entry']);
  }

  Future<List<OnlineTrack>> getRandomTracks({int size = 16}) async {
    final response = await _request(
      'getRandomSongs',
      parameters: {'size': '$size'},
    );
    final randomSongs = response['randomSongs'] as Map<String, dynamic>?;
    return _parseSongs(randomSongs?['song']);
  }

  Future<Uint8List?> fetchArtwork(String? url) async {
    if (url == null || url.isEmpty) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  String streamUrl(String songId) => _endpointUri(
        'stream',
        {'id': songId.replaceFirst('navidrome:', '')},
      ).toString();

  String downloadUrl(String songId) => _endpointUri(
        'download',
        {'id': songId.replaceFirst('navidrome:', '')},
      ).toString();

  String? coverArtUrl(String? coverArt, {int size = 600}) {
    if (coverArt == null || coverArt.isEmpty) return null;
    return _endpointUri('getCoverArt', {'id': coverArt, 'size': '$size'})
        .toString();
  }

  Future<bool> createPlaylist(String name, List<String> trackIds) async {
    try {
      if (trackIds.isEmpty) return false;
      final response = await _request(
        'createPlaylist',
        parameters: {
          'name': name,
          'songId': trackIds.map((id) => id.replaceFirst('navidrome:', '')).join(','),
        },
      );
      return response['playlist'] != null;
    } catch (e) {
      debugPrint('Create Navidrome playlist error: $e');
      return false;
    }
  }

  Future<bool> addToPlaylist(String playlistId, List<String> trackIds) async {
    try {
      if (trackIds.isEmpty) return false;
      await _request(
        'updatePlaylist',
        parameters: {
          'playlistId': playlistId,
          'songIdToAdd': trackIds.map((id) => id.replaceFirst('navidrome:', '')).join(','),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Add to Navidrome playlist error: $e');
      return false;
    }
  }

  Future<bool> removeFromPlaylist(String playlistId, List<String> trackIds) async {
    try {
      if (trackIds.isEmpty) return false;
      await _request(
        'updatePlaylist',
        parameters: {
          'playlistId': playlistId,
          'songIdToRemove': trackIds.map((id) => id.replaceFirst('navidrome:', '')).join(','),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Remove from Navidrome playlist error: $e');
      return false;
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    try {
      await _request(
        'deletePlaylist',
        parameters: {'id': playlistId},
      );
      return true;
    } catch (e) {
      debugPrint('Delete Navidrome playlist error: $e');
      return false;
    }
  }

  List<OnlineTrack> _parseSongs(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final id = map['id']?.toString() ?? '';
          return OnlineTrack(
            id: 'navidrome:$id',
            title: map['title']?.toString() ?? 'Bilinmeyen parça',
            artist: map['artist']?.toString() ?? 'Bilinmeyen sanatçı',
            album: map['album']?.toString(),
            duration: Duration(seconds: _asInt(map['duration'])),
            thumbnailUrl: coverArtUrl(map['coverArt']?.toString()),
            source: MusicSourceType.navidrome,
            streamUrl: streamUrl(id),
          );
        })
        .where((track) => track.id != 'navidrome:')
        .toList();
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, String> parameters = const {},
    NavidromeCredentials? credentials,
  }) async {
    final uri = _endpointUri(
      endpoint,
      parameters,
      credentials: credentials,
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Sunucu HTTP ${response.statusCode} döndürdü');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final subsonic = decoded['subsonic-response'] as Map<String, dynamic>?;
      if (subsonic == null) {
        throw const FormatException('Geçersiz Subsonic yanıtı');
      }
      if (subsonic['status'] != 'ok') {
        final error = subsonic['error'] as Map<String, dynamic>?;
        throw StateError(
          error?['message']?.toString() ?? 'Navidrome bağlantısı reddedildi',
        );
      }
      return subsonic;
    } finally {
      client.close(force: true);
    }
  }

  Uri _endpointUri(
    String endpoint,
    Map<String, String> parameters, {
    NavidromeCredentials? credentials,
  }) {
    final account = credentials ?? _credentials;
    if (account == null) {
      throw StateError('Navidrome hesabı bağlı değil');
    }
    final salt = _salt();
    final token =
        md5.convert(utf8.encode('${account.password}$salt')).toString();
    return Uri.parse('${account.serverUrl}/rest/$endpoint.view').replace(
      queryParameters: {
        'u': account.username,
        't': token,
        's': salt,
        'v': _apiVersion,
        'c': 'Melodi',
        'f': 'json',
        ...parameters,
      },
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _salt() {
    final random = Random.secure();
    return List<int>.generate(12, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
