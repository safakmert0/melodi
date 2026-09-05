import 'dart:convert';
import 'dart:io';

class MusicBrainzMatch {
  const MusicBrainzMatch({
    this.recordingId,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.isrc,
  });

  final String? recordingId;
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final String? isrc;
}

class MusicBrainzService {
  const MusicBrainzService._();

  static DateTime? _lastRequest;

  static Future<MusicBrainzMatch?> findRecording({
    required String title,
    required String artist,
    String? album,
  }) async {
    // MusicBrainz asks non-commercial clients to remain near one request/sec.
    final last = _lastRequest;
    if (last != null) {
      final wait =
          const Duration(milliseconds: 1100) - DateTime.now().difference(last);
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }
    _lastRequest = DateTime.now();

    final terms = <String>['recording:"$title"', 'artist:"$artist"'];
    if (album != null && album.trim().isNotEmpty) terms.add('release:"$album"');
    final uri = Uri.https('musicbrainz.org', '/ws/2/recording', {
      'query': terms.join(' AND '),
      'fmt': 'json',
      'limit': '5',
    });
    final data = await _get(uri);
    final recordings = data?['recordings'] as List?;
    if (recordings == null || recordings.isEmpty) return null;
    final recording = Map<String, dynamic>.from(recordings.first as Map);
    final credits = recording['artist-credit'] as List? ?? const [];
    final artistName =
        credits.isEmpty ? null : (credits.first as Map)['name']?.toString();
    final releases = recording['releases'] as List? ?? const [];
    final release = releases.isEmpty
        ? null
        : Map<String, dynamic>.from(releases.first as Map);
    final tags = List<dynamic>.from(recording['tags'] as List? ?? const []);
    tags.sort((a, b) => ((b as Map)['count'] as num? ?? 0)
        .compareTo((a as Map)['count'] as num? ?? 0));
    final date = release?['date']?.toString() ??
        recording['first-release-date']?.toString();
    final isrcs = recording['isrcs'] as List? ?? const [];
    return MusicBrainzMatch(
      recordingId: recording['id']?.toString(),
      title: recording['title']?.toString(),
      artist: artistName,
      album: release?['title']?.toString(),
      genre: tags.isEmpty ? null : (tags.first as Map)['name']?.toString(),
      year: date != null && date.length >= 4
          ? int.tryParse(date.substring(0, 4))
          : null,
      isrc: isrcs.isEmpty ? null : isrcs.first.toString(),
    );
  }

  static Future<Map<String, dynamic>?> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      request.headers.set(
          'User-Agent', 'Melodi/5.0 (https://github.com/safakmert0/melodi)');
      final response =
          await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}
