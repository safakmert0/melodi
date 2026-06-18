import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../services/ytmusic_service.dart';

class DiscoveredAlbum {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final String? imageUrl;
  final int? year;
  final int? trackCount;

  const DiscoveredAlbum({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.imageUrl,
    this.year,
    this.trackCount,
  });

  factory DiscoveredAlbum.fromSpotifyJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List<dynamic>?)
            ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
            .join(', ') ??
        '';
    final artistsList = json['artists'] as List<dynamic>?;
    final artistId = (artistsList != null && artistsList.isNotEmpty
        ? (artistsList.first as Map<String, dynamic>)['id'] as String?
        : '') ?? '';
    final images = json['images'] as List<dynamic>?;
    final imageUrl = images != null && images.isNotEmpty
        ? (images.first as Map<String, dynamic>)['url'] as String?
        : null;
    final releaseDate = json['release_date'] as String?;
    final year = releaseDate != null && releaseDate.length >= 4
        ? int.tryParse(releaseDate.substring(0, 4))
        : null;

    return DiscoveredAlbum(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: artists,
      artistId: artistId,
      imageUrl: imageUrl,
      year: year,
      trackCount: json['total_tracks'] as int?,
    );
  }
}

class DiscoveredTrack {
  final String id;
  final String name;
  final String artist;
  final int durationMs;
  final int trackNumber;

  const DiscoveredTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.durationMs,
    required this.trackNumber,
  });

  factory DiscoveredTrack.fromSpotifyJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List<dynamic>?)
            ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
            .join(', ') ??
        '';
    return DiscoveredTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: artists,
      durationMs: json['duration_ms'] as int? ?? 0,
      trackNumber: json['track_number'] as int? ?? 0,
    );
  }
}

class DiscoveredArtist {
  final String id;
  final String name;
  final String? imageUrl;
  final int? followers;
  final List<String> genres;

  const DiscoveredArtist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.followers,
    this.genres = const [],
  });

  factory DiscoveredArtist.fromSpotifyJson(Map<String, dynamic> json) {
    final images = json['images'] as List<dynamic>?;
    final imageUrl = images != null && images.isNotEmpty
        ? (images.first as Map<String, dynamic>)['url'] as String?
        : null;
    final followersObj = json['followers'] as Map<String, dynamic>?;
    final followers = followersObj?['total'] as int?;
    final genresList = (json['genres'] as List<dynamic>?)
            ?.map((g) => g as String)
            .toList() ??
        [];

    return DiscoveredArtist(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: imageUrl,
      followers: followers,
      genres: genresList,
    );
  }
}

class AlbumDiscoveryService {
  final DatabaseService _db = DatabaseService.instance;
  final YTMusicService _ytmusic = YTMusicService();

  static const String _webApiBase = 'https://api.spotify.com/v1';
  static const String _clientId = '5f573c9620494bae87890c0f08a60293';
  static const String _clientSecret = '212476d9b0f3472eaa762d90b19b0ba8';

  String? _clientCredentialsToken;
  int _clientCredentialsExpiry = 0;

  Future<String?> _getToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_clientCredentialsToken != null && now < _clientCredentialsExpiry - 60) {
      return _clientCredentialsToken;
    }
    try {
      final credentials = base64Encode(
        utf8.encode('$_clientId:$_clientSecret'),
      );
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _clientCredentialsToken = body['access_token'] as String?;
      _clientCredentialsExpiry = now + (body['expires_in'] as int? ?? 3600);
      return _clientCredentialsToken;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _get(String path,
      {Map<String, String>? params}) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      var url = '$_webApiBase$path';
      if (params != null && params.isNotEmpty) {
        url += '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<DiscoveredAlbum>> getNewReleases({int limit = 20}) async {
    final cacheKey = 'discovery_new_releases';
    final cached = await _db.getCachedMix(cacheKey);
    if (cached != null) {
      final cachedAt = DateTime.parse(cached['generatedAt']!);
      if (DateTime.now().difference(cachedAt).inHours < 6) {
        final list = jsonDecode(cached['data']!) as List<dynamic>;
        return list
            .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final json = await _get('/browse/new-releases',
        params: {'limit': limit.toString(), 'country': 'US'});
    if (json == null) return [];
    final items = json['albums']?['items'] as List<dynamic>? ?? [];
    final albums = items
        .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
    await _db.cacheMix(cacheKey, jsonEncode(items));
    return albums;
  }

  Future<List<DiscoveredAlbum>> getAlbumsForArtist(String artistId,
      {int limit = 20}) async {
    final cacheKey = 'discovery_artist_albums_$artistId';
    final cached = await _db.getCachedMix(cacheKey);
    if (cached != null) {
      final cachedAt = DateTime.parse(cached['generatedAt']!);
      if (DateTime.now().difference(cachedAt).inHours < 6) {
        final list = jsonDecode(cached['data']!) as List<dynamic>;
        return list
            .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final json = await _get('/artists/$artistId/albums',
        params: {
          'limit': limit.toString(),
          'include_groups': 'album,single',
          'market': 'US',
        });
    if (json == null) return [];
    final items = json['items'] as List<dynamic>? ?? [];
    final albums = items
        .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
    await _db.cacheMix(cacheKey, jsonEncode(items));
    return albums;
  }

  Future<List<DiscoveredTrack>> getAlbumTracks(String albumId) async {
    final cacheKey = 'discovery_album_tracks_$albumId';
    final cached = await _db.getCachedMix(cacheKey);
    if (cached != null) {
      final cachedAt = DateTime.parse(cached['generatedAt']!);
      if (DateTime.now().difference(cachedAt).inHours < 6) {
        final list = jsonDecode(cached['data']!) as List<dynamic>;
        return list
            .map((e) => DiscoveredTrack.fromSpotifyJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final json = await _get('/albums/$albumId/tracks',
        params: {'limit': '50', 'market': 'US'});
    if (json == null) return [];
    final items = json['items'] as List<dynamic>? ?? [];
    final tracks = items
        .map((e) => DiscoveredTrack.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
    await _db.cacheMix(cacheKey, jsonEncode(items));
    return tracks;
  }

  Future<List<DiscoveredAlbum>> discoverByGenre(String genre,
      {int limit = 20}) async {
    final cacheKey = 'discovery_genre_${genre.toLowerCase()}';
    final cached = await _db.getCachedMix(cacheKey);
    if (cached != null) {
      final cachedAt = DateTime.parse(cached['generatedAt']!);
      if (DateTime.now().difference(cachedAt).inHours < 6) {
        final list = jsonDecode(cached['data']!) as List<dynamic>;
        return list
            .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final json = await _get('/search',
        params: {
          'q': 'genre:"$genre"',
          'type': 'album',
          'limit': limit.toString(),
          'market': 'US',
        });
    if (json == null) return [];
    final items = json['albums']?['items'] as List<dynamic>? ?? [];
    final albums = items
        .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
    await _db.cacheMix(cacheKey, jsonEncode(items));
    return albums;
  }

  Future<List<DiscoveredAlbum>> searchAlbums(String query,
      {int limit = 20}) async {
    final json = await _get('/search',
        params: {
          'q': query,
          'type': 'album',
          'limit': limit.toString(),
          'market': 'US',
        });
    if (json == null) return [];
    final items = json['albums']?['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => DiscoveredAlbum.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DiscoveredArtist>> searchArtists(String query,
      {int limit = 10}) async {
    final json = await _get('/search',
        params: {
          'q': query,
          'type': 'artist',
          'limit': limit.toString(),
          'market': 'US',
        });
    if (json == null) return [];
    final items = json['artists']?['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => DiscoveredArtist.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DiscoveredArtist?> getArtist(String artistId) async {
    final json = await _get('/artists/$artistId');
    if (json == null) return null;
    return DiscoveredArtist.fromSpotifyJson(json);
  }

  Future<List<YTMusicTrack>> getAlbumsFromYTMusic(String artistName) async {
    final query = '$artistName album';
    return await _ytmusic.search(query);
  }

}


