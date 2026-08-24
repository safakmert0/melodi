import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../music_source.dart';

class AppleMusicAuth {
  static const MethodChannel _channel = MethodChannel('com.melodi.apple_music_auth');

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod('requestAuthorization') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getDeveloperToken() async {
    try {
      return await _channel.invokeMethod('getDeveloperToken');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getUserToken() async {
    try {
      return await _channel.invokeMethod('getUserToken');
    } catch (_) {
      return null;
    }
  }

  static Future<void> openAppleMusicApp() async {
    try {
      await _channel.invokeMethod('openAppleMusicApp');
    } catch (_) {}
  }
}

class AppleMusicSource implements MusicSource {
  static const String _baseUrl = 'https://api.music.apple.com/v1';
  static const String _storefront = 'tr';

  String? _developerToken;
  String? _userToken;
  bool _authorized = false;

  @override
  MusicSourceType get type => MusicSourceType.appleMusic;

  @override
  String get name => 'Apple Music';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    if (!await _ensureAuthorized()) return [];

    try {
      final uri = Uri.parse('$_baseUrl/catalog/$_storefront/search')
          .replace(queryParameters: {
        'term': query,
        'types': 'songs',
        'limit': limit.toString(),
      });

      final response = await _authenticatedGet(uri);
      if (response == null) return [];

      final data = response['results']?['songs']?['data'] as List?;
      if (data == null) return [];

      return data
          .whereType<Map<String, dynamic>>()
          .map((song) => _parseTrack(song))
          .whereType<OnlineTrack>()
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('Apple Music search error: $e');
      return [];
    }
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    if (!await _ensureAuthorized()) return null;

    try {
      final trackId = track.id;
      if (trackId.isEmpty) return null;

      final uri = Uri.parse('$_baseUrl/catalog/$_storefront/songs/$trackId');
      final response = await _authenticatedGet(uri);
      if (response == null) return null;

      final data = response['data'] as List?;
      if (data == null || data.isEmpty) return null;

      final attributes = data.first['attributes'] as Map<String, dynamic>?;
      if (attributes == null) return null;

      return attributes['previews']?[0]?['url'] as String?;
    } catch (e) {
      debugPrint('Apple Music stream error: $e');
      return null;
    }
  }

  Future<bool> _ensureAuthorized() async {
    if (_authorized && _developerToken != null && _userToken != null) {
      return true;
    }

    final available = await AppleMusicAuth.isAvailable();
    if (!available) return false;

    final authorized = await AppleMusicAuth.requestAuthorization();
    if (!authorized) return false;

    _developerToken = await AppleMusicAuth.getDeveloperToken();
    _userToken = await AppleMusicAuth.getUserToken();

    _authorized = _developerToken != null && _userToken != null;
    return _authorized;
  }

  Future<Map<String, dynamic>?> _authenticatedGet(Uri uri) async {
    if (_developerToken == null || _userToken == null) return null;

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $_developerToken');
      request.headers.set('Music-User-Token', _userToken!);
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('Apple Music API error: ${response.statusCode}');
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Apple Music request error: $e');
      return null;
    }
  }

  OnlineTrack? _parseTrack(Map<String, dynamic> song) {
    try {
      final id = song['id'] as String? ?? '';
      if (id.isEmpty) return null;

      final attributes = song['attributes'] as Map<String, dynamic>?;
      if (attributes == null) return null;

      final title = attributes['name'] as String? ?? '';
      final artist = attributes['artistName'] as String? ?? '';
      final album = attributes['albumName'] as String?;
      final durationMs = attributes['durationInMillis'] as int? ?? 0;
      final artwork = attributes['artwork'] as Map<String, dynamic>?;
      String? thumbnailUrl;
      if (artwork != null) {
        final width = artwork['width'] as int? ?? 300;
        final height = artwork['height'] as int? ?? 300;
        final url = artwork['url'] as String? ?? '';
        if (url.isNotEmpty) {
          thumbnailUrl = url
              .replaceAll('{w}', width.toString())
              .replaceAll('{h}', height.toString());
        }
      }

      return OnlineTrack(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: Duration(milliseconds: durationMs),
        thumbnailUrl: thumbnailUrl,
        source: MusicSourceType.appleMusic,
      );
    } catch (e) {
      debugPrint('Apple Music parse error: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {}

  Future<bool> isAvailable() async {
    return await AppleMusicAuth.isAvailable();
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists() async {
    if (!await _ensureAuthorized()) return [];

    try {
      final uri = Uri.parse('$_baseUrl/me/library/playlists')
          .replace(queryParameters: {'limit': '50'});

      final response = await _authenticatedGet(uri);
      if (response == null) return [];

      final data = response['data'] as List?;
      if (data == null) return [];

      return data
          .whereType<Map<String, dynamic>>()
          .map((p) => {
                'id': p['id'] as String? ?? '',
                'title': p['attributes']?['name'] as String? ?? 'Adsız liste',
                'description': p['attributes']?['description']?['standard'] as String?,
                'trackCount': p['attributes']?['trackCount'] as int? ?? 0,
                'artworkUrl': p['attributes']?['artwork']?['url'] as String?,
                'isOwner': true,
                'collaborative': false,
              })
          .toList();
    } catch (e) {
      debugPrint('Apple Music get playlists error: $e');
      return [];
    }
  }

  Future<List<OnlineTrack>> getPlaylistTracks(String playlistId) async {
    if (!await _ensureAuthorized()) return [];

    try {
      final uri = Uri.parse('$_baseUrl/me/library/playlists/$playlistId/tracks')
          .replace(queryParameters: {'limit': '100'});

      final response = await _authenticatedGet(uri);
      if (response == null) return [];

      final data = response['data'] as List?;
      if (data == null) return [];

      return data
          .whereType<Map<String, dynamic>>()
          .map((track) => _parseTrack(track))
          .whereType<OnlineTrack>()
          .toList();
    } catch (e) {
      debugPrint('Apple Music playlist tracks error: $e');
      return [];
    }
  }

  Future<bool> createPlaylist(
    String name,
    String? description,
    List<String> trackIds,
  ) async {
    if (!await _ensureAuthorized()) return false;

    try {
      final uri = Uri.parse('$_baseUrl/me/library/playlists');
      final client = http.Client();
      try {
        final request = http.Request('POST', uri)
          ..headers.addAll({
            'Authorization': 'Bearer $_developerToken',
            'Music-User-Token': _userToken!,
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'attributes': {'name': name, 'description': description},
            'relationships': {
              'tracks': {
                'data': trackIds.map((id) => {'id': id, 'type': 'songs'}).toList(),
              },
            },
          });
        final response = await client.send(request);
        return response.statusCode == 201;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Apple Music create playlist error: $e');
      return false;
    }
  }

  Future<bool> addTracksToPlaylist(String playlistId, List<String> trackIds) async {
    if (!await _ensureAuthorized()) return false;

    try {
      final uri = Uri.parse('$_baseUrl/me/library/playlists/$playlistId/tracks');
      final client = http.Client();
      try {
        final request = http.Request('POST', uri)
          ..headers.addAll({
            'Authorization': 'Bearer $_developerToken',
            'Music-User-Token': _userToken!,
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'data': trackIds.map((id) => {'id': id, 'type': 'songs'}).toList(),
          });
        final response = await client.send(request);
        return response.statusCode == 201;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Apple Music add tracks error: $e');
      return false;
    }
  }

  Future<bool> removeTracksFromPlaylist(String playlistId, List<String> trackIds) async {
    if (!await _ensureAuthorized()) return false;

    try {
      final uri = Uri.parse('$_baseUrl/me/library/playlists/$playlistId/tracks');
      final client = http.Client();
      try {
        final request = http.Request('DELETE', uri)
          ..headers.addAll({
            'Authorization': 'Bearer $_developerToken',
            'Music-User-Token': _userToken!,
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'data': trackIds.map((id) => {'id': id, 'type': 'songs'}).toList(),
          });
        final response = await client.send(request);
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Apple Music remove tracks error: $e');
      return false;
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    if (!await _ensureAuthorized()) return false;

    try {
      final uri = Uri.parse('$_baseUrl/me/library/playlists/$playlistId');
      final client = http.Client();
      try {
        final request = http.Request('DELETE', uri)
          ..headers.addAll({
            'Authorization': 'Bearer $_developerToken',
            'Music-User-Token': _userToken!,
          });
        final response = await client.send(request);
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Apple Music delete playlist error: $e');
      return false;
    }
  }
}