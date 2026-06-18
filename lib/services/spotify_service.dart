import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SpotifyAuthConfig {
  SpotifyAuthConfig._();

  static const String tokenEndpoint = 'https://open.spotify.com/api/token';
  static const String clientTokenEndpoint =
      'https://clienttoken.spotify.com/v1/clienttoken';
  static const String graphqlEndpoint =
      'https://api-partner.spotify.com/pathfinder/v1/query';
  static const String webApiBase = 'https://api.spotify.com/v1';
  static const String accountsEndpoint =
      'https://accounts.spotify.com/api/token';
  static const String clientVersionFallback = '1.2.87.311.g2db0c2c4';
  static const String hashLibraryV3 =
      '973e511ca44261fda7eebac8b653155e7caee3675abb4fb110cc1b8c78b091c3';
  static const String hashFetchPlaylist =
      '32b05e92e438438408674f95d0fdad8082865dc32acd55bd97f5113b8579092b';
  static const String hashFetchLibraryTracks =
      '087278b20b743578a6262c2b0b4bcd20d879c503cc359a2285baf083ef944240';
  static const String hashHome =
      '23e37f2e58d82d567f27080101d36609009d8c3676457b1086cb0acc55b72a5d';
  static const String hashSearchDesktop =
      '75bbf6bfcfdf85b8fc828417bfad92b7cd66bf7f556d85670f4da8292373ebec';
  static const String spDcCookieName = 'sp_dc';
  static const String totpVersion = '61';
  static const int totpInterval = 30;
  static const int totpDigits = 6;
  static const List<int> secretCipher = [
    44, 55, 47, 42, 70, 40, 34, 114, 76, 74,
    50, 111, 120, 97, 75, 76, 94, 102, 43, 69,
    49, 120, 118, 80, 64, 78,
  ];
  static const String spotdlClientId =
      '5f573c9620494bae87890c0f08a60293';
  static const String spotdlClientSecret =
      '212476d9b0f3472eaa762d90b19b0ba8';
}

class SpotifyTotp {
  SpotifyTotp._();

  static String generate(int serverTimeSeconds) {
    final secret = _deriveSecret();
    return _generateTotp(secret, serverTimeSeconds);
  }

  static List<int> _deriveSecret() {
    final transformed = List<int>.generate(
      SpotifyAuthConfig.secretCipher.length,
      (i) => SpotifyAuthConfig.secretCipher[i] ^ ((i % 33) + 9),
    );
    final joined = transformed.join('');
    final hexStr =
        utf8.encode(joined).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _hexDecode(hexStr);
  }

  static List<int> _hexDecode(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static String _generateTotp(List<int> secret, int timeSeconds) {
    final counter = (timeSeconds / SpotifyAuthConfig.totpInterval).floor();
    final counterData = ByteData(8)..setInt64(0, counter, Endian.big);
    final counterBytes = counterData.buffer.asUint8List();

    final hmac = Hmac(sha1, secret);
    final digest = hmac.convert(counterBytes);
    final hash = digest.bytes;

    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    final otp = binary % pow(10, SpotifyAuthConfig.totpDigits).toInt();
    return otp.toString().padLeft(SpotifyAuthConfig.totpDigits, '0');
  }
}

class SpotifySession {
  final String accessToken;
  final String refreshToken;
  final int expiresAtEpoch;
  final String username;
  final String clientId;

  const SpotifySession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtEpoch,
    required this.username,
    required this.clientId,
  });

  bool get isExpired => DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiresAtEpoch;

  bool get isExpiringSoon =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiresAtEpoch - 300;
}

class SpotifyPlaylistItem {
  final String id;
  final String name;
  final String ownerId;
  final String? imageUrl;
  final int trackCount;

  const SpotifyPlaylistItem({
    required this.id,
    required this.name,
    required this.ownerId,
    this.imageUrl,
    this.trackCount = 0,
  });
}

class SpotifyTrackItem {
  final String id;
  final String name;
  final List<String> artists;
  final String? albumName;
  final String? albumId;
  final String? albumImageUrl;
  final int durationMs;
  final String uri;

  const SpotifyTrackItem({
    required this.id,
    required this.name,
    required this.artists,
    this.albumName,
    this.albumId,
    this.albumImageUrl,
    this.durationMs = 0,
    required this.uri,
  });
}

class SpotifyService {
  String? _accessToken;
  String? _refreshToken;
  int _expiresAtEpoch = 0;
  String? _username;
  String? _clientId;
  String? _clientToken;
  String? _clientCredentialsToken;
  int _clientCredentialsExpiry = 0;
  String? _spTDeviceId;
  String? _cachedClientVersion;

  bool get isConnected => _accessToken != null;
  String? get username => _username;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get clientToken => _clientToken;

  bool get isExpiringSoon =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 >= _expiresAtEpoch - 300;

  bool get _isExpired =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 >= _expiresAtEpoch;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36';

  static final RegExp _clientVersionRegex =
      RegExp(r'"clientVersion"\s*:\s*"([^"]+)"');

  String getClientVersion() {
    if (_cachedClientVersion != null) return _cachedClientVersion!;
    try {
      return _cachedClientVersion ??= SpotifyAuthConfig.clientVersionFallback;
    } catch (_) {
      return SpotifyAuthConfig.clientVersionFallback;
    }
  }

  Future<void> scrapeClientVersion() async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('https://open.spotify.com'));
        request.headers.set('User-Agent', _userAgent);
        final response = await request.close();

        response.headers.forEach((name, values) {
          if (name.toLowerCase() == 'set-cookie') {
            for (final val in values) {
              if (val.startsWith('sp_t=')) {
                final parts = val.split(';');
                if (parts.isNotEmpty) {
                  final value = parts[0].substring('sp_t='.length);
                  if (value.isNotEmpty && _spTDeviceId == null) {
                    _spTDeviceId = value;
                  }
                }
              }
            }
          }
        });

        final body = await response.transform(utf8.decoder).join();
        final match = _clientVersionRegex.firstMatch(body);
        if (match != null && match.group(1) != null) {
          _cachedClientVersion = match.group(1);
        }
      } finally {
        client.close();
      }
    } catch (_) {
      _cachedClientVersion ??= SpotifyAuthConfig.clientVersionFallback;
    }
  }

  Future<int?> _getServerTime() async {
    try {
      final client = HttpClient();
      try {
        final request = await client.headUrl(Uri.parse('https://open.spotify.com/'));
        request.headers.set('User-Agent', 'Mozilla/5.0');
        final response = await request.close();
        final dateHeader = response.headers.value('Date');
        if (dateHeader != null) {
          final date = HttpDate.parse(dateHeader);
          return date.millisecondsSinceEpoch ~/ 1000;
        }
        return null;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  String? extractUsernameFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = utf8.decode(base64Url.decode(
          parts[1].padRight(parts[1].length + ((4 - parts[1].length % 4) % 4), '=')));
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return (json['sub'] ?? json['username']) as String?;
    } catch (_) {
      return null;
    }
  }

  Future<SpotifySession?> getAccessToken(String spDcCookie) async {
    try {
      final serverTime = await _getServerTime() ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final totp = SpotifyTotp.generate(serverTime);

      final url = Uri.parse(
        '${SpotifyAuthConfig.tokenEndpoint}'
        '?reason=transport'
        '&productType=web-player'
        '&totp=$totp'
        '&totpServer=$totp'
        '&totpVer=${SpotifyAuthConfig.totpVersion}',
      );

      final response = await http.get(
        url,
        headers: {
          'Cookie': '${SpotifyAuthConfig.spDcCookieName}=$spDcCookie',
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'App-Platform': 'WebPlayer',
          'Referer': 'https://open.spotify.com/',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Spotify token endpoint returned HTTP ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      final isAnonymous = body['isAnonymous'] as bool? ?? true;
      if (isAnonymous) {
        debugPrint('Spotify token is anonymous - sp_dc cookie is invalid or expired');
        return null;
      }

      final accessToken = body['accessToken'] as String?;
      final expiresMs = body['accessTokenExpirationTimestampMs'] as int? ?? 0;
      final clientId = body['clientId'] as String? ?? '';
      final usernameFromResponse = body['username'] as String? ?? '';

      if (accessToken == null) return null;

      final jwtUsername = extractUsernameFromJwt(accessToken);
      final resolvedUsername = jwtUsername ?? usernameFromResponse;

      _accessToken = accessToken;
      _refreshToken = spDcCookie;
      _expiresAtEpoch = expiresMs ~/ 1000;
      _username = resolvedUsername.isNotEmpty ? resolvedUsername : null;
      _clientId = clientId;

      return SpotifySession(
        accessToken: accessToken,
        refreshToken: spDcCookie,
        expiresAtEpoch: expiresMs ~/ 1000,
        username: resolvedUsername,
        clientId: clientId,
      );
    } catch (e) {
      debugPrint('Spotify getAccessToken failed: $e');
      return null;
    }
  }

  Future<SpotifySession?> refreshAccessToken() async {
    if (_refreshToken == null) return null;
    return getAccessToken(_refreshToken!);
  }

  Future<String?> getClientCredentialsToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_clientCredentialsToken != null && now < _clientCredentialsExpiry - 60) {
      return _clientCredentialsToken;
    }

    try {
      final credentials = base64Encode(
        utf8.encode('${SpotifyAuthConfig.spotdlClientId}:${SpotifyAuthConfig.spotdlClientSecret}'),
      );

      final response = await http.post(
        Uri.parse(SpotifyAuthConfig.accountsEndpoint),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['access_token'] as String?;
      if (token != null) {
        _clientCredentialsToken = token;
        _clientCredentialsExpiry = now + 3600;
      }
      return token;
    } catch (e) {
      debugPrint('getClientCredentialsToken failed: $e');
      return null;
    }
  }

  Future<String?> getClientToken(String clientId) async {
    try {
      final clientVersion = getClientVersion();
      final deviceId = _spTDeviceId ??
          '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(100000)}';

      final requestBody = jsonEncode({
        'client_data': {
          'client_version': clientVersion,
          'client_id': clientId,
          'js_sdk_data': {
            'device_brand': 'unknown',
            'device_model': 'unknown',
            'os': 'windows',
            'os_version': 'NT 10.0',
            'device_id': deviceId,
            'device_type': 'computer',
          },
        },
      });

      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse(SpotifyAuthConfig.clientTokenEndpoint),
        );
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('Accept', 'application/json');
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36');
        request.write(requestBody);

        final response = await request.close();
        if (response.statusCode != 200) return null;

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        if (json['response_type'] == 'RESPONSE_GRANTED_TOKEN_RESPONSE') {
          final token = json['granted_token']?['token'] as String?;
          if (token != null) _clientToken = token;
          return token;
        }
        return null;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('getClientToken failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _executeGraphQL({
    required String operationName,
    required String variables,
    required String hash,
  }) async {
    if (_accessToken == null) return null;

    String? clientToken = _clientToken;
    if (clientToken == null && _clientId != null) {
      clientToken = await getClientToken(_clientId!);
      if (clientToken == null) return null;
    }

    final encodedVariables = Uri.encodeQueryComponent(variables);
    final extensions = jsonEncode({
      'persistedQuery': {
        'version': 1,
        'sha256Hash': hash,
      },
    });
    final encodedExtensions = Uri.encodeQueryComponent(extensions);

    final url = '${SpotifyAuthConfig.graphqlEndpoint}'
        '?operationName=$operationName'
        '&variables=$encodedVariables'
        '&extensions=$encodedExtensions';

    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'Client-Token': clientToken ?? '',
      'Accept': 'application/json',
      'App-Platform': 'WebPlayer',
      'Spotify-App-Version': getClientVersion(),
      'Origin': 'https://open.spotify.com',
      'Referer': 'https://open.spotify.com/',
      'User-Agent': _userAgent,
    };

    var response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed != null) {
        _clientToken = null;
        if (_clientId != null) {
          clientToken = await getClientToken(_clientId!);
          if (clientToken != null) {
            headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
            headers['Client-Token'] = clientToken;
            response = await http.get(Uri.parse(url), headers: headers);
          }
        }
      }
    } else if (response.statusCode == 400 && _clientId != null) {
      _clientToken = null;
      clientToken = await getClientToken(_clientId!);
      if (clientToken != null) {
        headers['Client-Token'] = clientToken;
        response = await http.get(Uri.parse(url), headers: headers);
      }
    }

    if (response.statusCode != 200) return null;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.containsKey('errors')) {
        debugPrint('GraphQL errors in $operationName: ${body['errors']}');
      }
      return body;
    } catch (_) {
      return null;
    }
  }

  Future<List<SpotifyPlaylistItem>> getUserPlaylists({
    int limit = 50,
    int offset = 0,
    String? folderUri,
  }) async {
    try {
      final variables = jsonEncode({
        'filters': ['Playlists'],
        'order': null,
        'textFilter': '',
        'features': ['LIKED_SONGS', 'YOUR_EPISODES'],
        'limit': limit,
        'offset': offset,
        if (folderUri != null) 'folderUri': folderUri,
      });

      final responseJson = await _executeGraphQL(
        operationName: 'libraryV3',
        variables: variables,
        hash: SpotifyAuthConfig.hashLibraryV3,
      );

      if (responseJson == null) return [];

      return _parseLibraryPage(responseJson);
    } catch (e) {
      debugPrint('getUserPlaylists failed: $e');
      return [];
    }
  }

  List<SpotifyPlaylistItem> _parseLibraryPage(Map<String, dynamic> responseJson) {
    try {
      final items = responseJson['data']?['me']?['libraryV3']?['items'] as List<dynamic>?;
      if (items == null) return [];

      final playlists = <SpotifyPlaylistItem>[];

      for (final element in items) {
        try {
          final wrapper = element as Map<String, dynamic>;
          final item = wrapper['item'] as Map<String, dynamic>?;
          if (item == null) continue;

          final data = item['data'] as Map<String, dynamic>?;
          if (data == null) continue;

          final dataTypeName = data['__typename'] as String?;
          final uri = data['uri'] as String?;

          if (dataTypeName == 'Folder' || (uri?.contains(':folder:') == true)) {
            continue;
          }

          if (dataTypeName != 'Playlist') continue;
          if (uri == null || !uri.startsWith('spotify:playlist:')) continue;

          final playlistId = uri.replaceFirst('spotify:playlist:', '');
          final name = data['name'] as String? ?? 'Untitled';

          final ownerData = data['ownerV2'] as Map<String, dynamic>?;
          final ownerId = ownerData?['data']?['username'] as String? ?? '';

          String? imageUrl;
          final images = data['images'] as Map<String, dynamic>?;
          final imageItems = images?['items'] as List<dynamic>?;
          if (imageItems != null && imageItems.isNotEmpty) {
            final sources = (imageItems.first as Map<String, dynamic>)['sources'] as List<dynamic>?;
            if (sources != null && sources.isNotEmpty) {
              imageUrl = (sources.first as Map<String, dynamic>)['url'] as String?;
            }
          }

          final content = data['content'] as Map<String, dynamic>?;
          final trackCount = content?['totalCount'] as int? ?? 0;

          playlists.add(SpotifyPlaylistItem(
            id: playlistId,
            name: name,
            ownerId: ownerId,
            imageUrl: imageUrl,
            trackCount: trackCount,
          ));
        } catch (_) {}
      }

      return playlists;
    } catch (e) {
      debugPrint('_parseLibraryPage failed: $e');
      return [];
    }
  }

  Future<List<SpotifyTrackItem>> getPlaylistTracks(String playlistId) async {
    try {
      final token = await getClientCredentialsToken();
      if (token != null) {
        final webApiTracks = await _tryGetPlaylistTracksViaWebApi(playlistId, token);
        if (webApiTracks != null) return webApiTracks;
      }

      return await _tryGetPlaylistTracksViaGraphQL(playlistId);
    } catch (e) {
      debugPrint('getPlaylistTracks failed: $e');
      return [];
    }
  }

  Future<List<SpotifyTrackItem>?> _tryGetPlaylistTracksViaWebApi(
      String playlistId, String token) async {
    try {
      final allTracks = <SpotifyTrackItem>[];
      String? url = '${SpotifyAuthConfig.webApiBase}/playlists/$playlistId/tracks'
          '?limit=50&offset=0'
          '&fields=items(track(id,name,uri,duration_ms,explicit,external_ids,'
          'artists(id,name),album(id,name,images))),next';

      while (url != null) {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 404) return null;
        if (response.statusCode != 200) return null;

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final items = body['items'] as List<dynamic>? ?? [];
        url = body['next'] as String?;

        for (final element in items) {
          try {
            final wrapper = element as Map<String, dynamic>;
            final trackObj = wrapper['track'] as Map<String, dynamic>?;
            if (trackObj == null) continue;

            final id = trackObj['id'] as String?;
            final name = trackObj['name'] as String?;
            if (id == null || name == null) continue;

            final artists = (trackObj['artists'] as List<dynamic>?)
                    ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
                    .where((a) => a.isNotEmpty)
                    .toList() ??
                [];

            final albumObj = trackObj['album'] as Map<String, dynamic>?;
            final albumName = albumObj?['name'] as String?;
            final albumId = albumObj?['id'] as String?;
            String? albumImageUrl;
            final images = albumObj?['images'] as List<dynamic>?;
            if (images != null && images.isNotEmpty) {
              albumImageUrl = (images.first as Map<String, dynamic>)['url'] as String?;
            }

            allTracks.add(SpotifyTrackItem(
              id: id,
              name: name,
              artists: artists,
              albumName: albumName,
              albumId: albumId,
              albumImageUrl: albumImageUrl,
              durationMs: trackObj['duration_ms'] as int? ?? 0,
              uri: trackObj['uri'] as String? ?? 'spotify:track:$id',
            ));
          } catch (_) {}
        }
      }

      return allTracks;
    } catch (e) {
      debugPrint('tryGetPlaylistTracksViaWebApi failed: $e');
      return null;
    }
  }

  Future<List<SpotifyTrackItem>> _tryGetPlaylistTracksViaGraphQL(
      String playlistId) async {
    final uri = 'spotify:playlist:$playlistId';
    final allTracks = <SpotifyTrackItem>[];
    var offset = 0;
    const pageSize = 100;

    while (true) {
      final variables = jsonEncode({
        'uri': uri,
        'offset': offset,
        'limit': pageSize,
        'enableWatchFeedEntrypoint': false,
      });

      final responseJson = await _executeGraphQL(
        operationName: 'fetchPlaylist',
        variables: variables,
        hash: SpotifyAuthConfig.hashFetchPlaylist,
      );

      if (responseJson == null) break;

      final page = _parsePlaylistTracksGraphQLResponse(responseJson);
      allTracks.addAll(page.$1);

      if (page.$2 < pageSize) break;
      offset += pageSize;
    }

    return allTracks;
  }

  (List<SpotifyTrackItem>, int) _parsePlaylistTracksGraphQLResponse(
      Map<String, dynamic> responseJson) {
    try {
      final items = responseJson['data']?['playlistV2']?['content']?['items'] as List<dynamic>?;
      if (items == null) return ([], 0);

      final rawItemCount = items.length;
      final tracks = <SpotifyTrackItem>[];

      for (final element in items) {
        try {
          final wrapper = element as Map<String, dynamic>;
          final itemV2 = wrapper['itemV2'] as Map<String, dynamic>?;
          final data = itemV2?['data'] as Map<String, dynamic>?;
          if (data == null) continue;

          final typeName = data['__typename'] as String?;
          if (typeName != null && typeName != 'Track' && typeName != 'TrackResponseWrapper') continue;

          final uri = data['uri'] as String?;
          if (uri == null || !uri.startsWith('spotify:track:')) continue;

          final trackId = uri.replaceFirst('spotify:track:', '');
          final name = data['name'] as String? ?? 'Unknown';

          final durationMs = data['trackDuration']?['totalMilliseconds'] as int?
              ?? data['duration']?['totalMilliseconds'] as int?
              ?? 0;

          final artistItems = data['artists']?['items'] as List<dynamic>?;
          final artists = artistItems
                  ?.map((a) => (a as Map<String, dynamic>)['profile']?['name'] as String? ?? '')
                  .where((a) => a.isNotEmpty)
                  .toList() ??
              [];

          final albumData = data['albumOfTrack'] as Map<String, dynamic>?;
          final albumName = albumData?['name'] as String?;
          final albumUri = albumData?['uri'] as String?;
          final albumId = albumUri?.replaceFirst('spotify:album:', '');

          String? albumImageUrl;
          final sources = albumData?['coverArt']?['sources'] as List<dynamic>?;
          if (sources != null && sources.isNotEmpty) {
            albumImageUrl = (sources.first as Map<String, dynamic>)['url'] as String?;
          }

          tracks.add(SpotifyTrackItem(
            id: trackId,
            name: name,
            artists: artists,
            albumName: albumName,
            albumId: albumId,
            albumImageUrl: albumImageUrl,
            durationMs: durationMs,
            uri: uri,
          ));
        } catch (_) {}
      }

      return (tracks, rawItemCount);
    } catch (e) {
      debugPrint('_parsePlaylistTracksGraphQLResponse failed: $e');
      return ([], 0);
    }
  }

  Future<List<SpotifyTrackItem>> getLikedSongs({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final variables = jsonEncode({
        'offset': offset,
        'limit': limit,
      });

      final responseJson = await _executeGraphQL(
        operationName: 'fetchLibraryTracks',
        variables: variables,
        hash: SpotifyAuthConfig.hashFetchLibraryTracks,
      );

      if (responseJson == null) return [];

      return _parseLibraryTracksResponse(responseJson);
    } catch (e) {
      debugPrint('getLikedSongs failed: $e');
      return [];
    }
  }

  List<SpotifyTrackItem> _parseLibraryTracksResponse(
      Map<String, dynamic> responseJson) {
    try {
      final items = responseJson['data']?['me']?['library']?['tracks']?['items'] as List<dynamic>?;
      if (items == null) return [];

      final tracks = <SpotifyTrackItem>[];

      for (final element in items) {
        try {
          final wrapper = element as Map<String, dynamic>;
          final data = wrapper['item']?['data'] as Map<String, dynamic>?;
          if (data == null) continue;

          final uri = data['uri'] as String?;
          if (uri == null || !uri.startsWith('spotify:track:')) continue;

          final trackId = uri.replaceFirst('spotify:track:', '');
          final name = data['name'] as String? ?? 'Unknown';

          final durationMs = data['trackDuration']?['totalMilliseconds'] as int?
              ?? data['duration']?['totalMilliseconds'] as int?
              ?? 0;

          final artistItems = data['artists']?['items'] as List<dynamic>?;
          final artists = artistItems
                  ?.map((a) => (a as Map<String, dynamic>)['profile']?['name'] as String? ?? '')
                  .where((a) => a.isNotEmpty)
                  .toList() ??
              [];

          final albumData = data['albumOfTrack'] as Map<String, dynamic>?;
          final albumName = albumData?['name'] as String?;
          final albumUri = albumData?['uri'] as String?;
          final albumId = albumUri?.replaceFirst('spotify:album:', '');

          String? albumImageUrl;
          final sources = albumData?['coverArt']?['sources'] as List<dynamic>?;
          if (sources != null && sources.isNotEmpty) {
            albumImageUrl = (sources.first as Map<String, dynamic>)['url'] as String?;
          }

          tracks.add(SpotifyTrackItem(
            id: trackId,
            name: name,
            artists: artists,
            albumName: albumName,
            albumId: albumId,
            albumImageUrl: albumImageUrl,
            durationMs: durationMs,
            uri: uri,
          ));
        } catch (_) {}
      }

      return tracks;
    } catch (e) {
      debugPrint('_parseLibraryTracksResponse failed: $e');
      return [];
    }
  }

  Future<List<SpotifyTrackItem>> searchTracks(String query,
      {int limit = 8, String market = 'US'}) async {
    if (_accessToken == null) return [];

    try {
      final url = '${SpotifyAuthConfig.webApiBase}/search'
          '?type=track&limit=$limit&market=$market'
          '&q=${Uri.encodeQueryComponent(query)}';

      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed != null) {
          response = await http.get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${refreshed.accessToken}',
              'Accept': 'application/json',
            },
          );
        }
      }

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['tracks']?['items'] as List<dynamic>? ?? [];

      return items.map((element) {
        try {
          final trackObj = element as Map<String, dynamic>;
          final id = trackObj['id'] as String?;
          final name = trackObj['name'] as String?;
          if (id == null || name == null) return null;

          final artists = (trackObj['artists'] as List<dynamic>?)
                  ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
                  .where((a) => a.isNotEmpty)
                  .toList() ??
              [];

          final albumObj = trackObj['album'] as Map<String, dynamic>?;
          final albumName = albumObj?['name'] as String?;
          final albumId = albumObj?['id'] as String?;
          String? albumImageUrl;
          final images = albumObj?['images'] as List<dynamic>?;
          if (images != null && images.isNotEmpty) {
            albumImageUrl = (images.first as Map<String, dynamic>)['url'] as String?;
          }

          return SpotifyTrackItem(
            id: id,
            name: name,
            artists: artists,
            albumName: albumName,
            albumId: albumId,
            albumImageUrl: albumImageUrl,
            durationMs: trackObj['duration_ms'] as int? ?? 0,
            uri: trackObj['uri'] as String? ?? 'spotify:track:$id',
          );
        } catch (_) {
          return null;
        }
      }).where((e) => e != null).cast<SpotifyTrackItem>().toList();
    } catch (e) {
      debugPrint('searchTracks failed: $e');
      return [];
    }
  }
}
