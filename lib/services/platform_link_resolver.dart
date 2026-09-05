import 'dart:convert';
import 'dart:io';

class PlatformLinkResult {
  const PlatformLinkResult(this.links, {this.title, this.artist});

  final Map<String, String> links;
  final String? title;
  final String? artist;
}

/// Cross-platform resolver chain used by the SpotiFLAC projects.
class PlatformLinkResolver {
  const PlatformLinkResolver._();

  static Future<PlatformLinkResult> resolve(String inputUrl) async {
    final merged = <String, String>{};
    String? title;
    String? artist;
    for (final resolver in <Future<dynamic> Function()>[
      () => _getJson(Uri.parse('https://api.song.link/v1-alpha.1/links')
          .replace(queryParameters: {'url': inputUrl})),
      () => _getJson(Uri.parse('https://api.unitune.art/v1-alpha.1/links')
          .replace(queryParameters: {'url': inputUrl})),
      () => _postJson(
          Uri.parse('https://squigly.link/api/create'), {'url': inputUrl}),
    ]) {
      try {
        final data = await resolver().timeout(const Duration(seconds: 10));
        if (data is! Map) continue;
        final map = Map<String, dynamic>.from(data);
        title ??= map['title']?.toString();
        artist ??= map['artist']?.toString() ?? map['artistName']?.toString();
        final metadata = _findMetadata(map);
        title ??= metadata.$1;
        artist ??= metadata.$2;
        _collectLinks(map, merged);
      } catch (_) {}
    }
    merged.putIfAbsent(_platformFor(inputUrl), () => inputUrl);
    return PlatformLinkResult(merged, title: title, artist: artist);
  }

  static (String?, String?) _findMetadata(dynamic value) {
    if (value is Map) {
      final title = value['title']?.toString();
      final artist = (value['artistName'] ?? value['artist'])?.toString();
      if (title != null && title.isNotEmpty) return (title, artist);
      for (final child in value.values) {
        final found = _findMetadata(child);
        if (found.$1 != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findMetadata(child);
        if (found.$1 != null) return found;
      }
    }
    return (null, null);
  }

  static void _collectLinks(dynamic value, Map<String, String> output,
      [String? key]) {
    if (value is Map) {
      for (final entry in value.entries) {
        _collectLinks(entry.value, output, entry.key.toString());
      }
    } else if (value is List) {
      for (final item in value) {
        _collectLinks(item, output, key);
      }
    } else if (value is String && value.startsWith('http')) {
      final platform = key == null ? _platformFor(value) : _normalizeKey(key);
      if (_allowedUrl(value)) output.putIfAbsent(platform, () => value);
    }
  }

  static bool _allowedUrl(String value) {
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    return const [
      'spotify.com',
      'deezer.com',
      'tidal.com',
      'qobuz.com',
      'music.apple.com',
      'music.amazon.com',
      'youtube.com',
      'youtu.be',
      'soundcloud.com',
    ].any((domain) => host == domain || host.endsWith('.$domain'));
  }

  static String _platformFor(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('spotify')) return 'spotify';
    if (host.contains('deezer')) return 'deezer';
    if (host.contains('tidal')) return 'tidal';
    if (host.contains('qobuz')) return 'qobuz';
    if (host.contains('apple')) return 'appleMusic';
    if (host.contains('amazon')) return 'amazonMusic';
    if (host.contains('youtube') || host.contains('youtu.be'))
      return 'youtubeMusic';
    if (host.contains('soundcloud')) return 'soundcloud';
    return 'source';
  }

  static String _normalizeKey(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('apple')) return 'appleMusic';
    if (lower.contains('amazon')) return 'amazonMusic';
    if (lower.contains('youtube')) return 'youtubeMusic';
    return lower.replaceAll(RegExp('[^a-z0-9]'), '');
  }

  static Future<dynamic> _getJson(Uri uri) async => _request(uri, 'GET');

  static Future<dynamic> _postJson(Uri uri, Object body) =>
      _request(uri, 'POST', body: jsonEncode(body));

  static Future<dynamic> _request(Uri uri, String method,
      {String? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = method == 'POST'
          ? await client.postUrl(uri)
          : await client.getUrl(uri);
      request.headers.set('User-Agent', 'Melodi/5.0');
      request.headers.set('Accept', 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return jsonDecode(await response.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }
}
