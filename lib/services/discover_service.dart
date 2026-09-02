import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum DiscoverCategory {
  yeniCikanlar,
  trendler,
  top10,
  top50,
  topluluk,
}

extension DiscoverCategoryMeta on DiscoverCategory {
  String get title {
    switch (this) {
      case DiscoverCategory.yeniCikanlar:
        return 'Yeni Çıkanlar';
      case DiscoverCategory.trendler:
        return 'Trendler';
      case DiscoverCategory.top10:
        return 'Top 10';
      case DiscoverCategory.top50:
        return 'Top 50';
      case DiscoverCategory.topluluk:
        return 'Topluluk Listeleri';
    }
  }

  String get subtitle {
    switch (this) {
      case DiscoverCategory.yeniCikanlar:
        return 'Yeni çıkan parçalar';
      case DiscoverCategory.trendler:
        return 'Şu an popüler';
      case DiscoverCategory.top10:
        return 'En çok dinlenen 10';
      case DiscoverCategory.top50:
        return 'En çok dinlenen 50';
      case DiscoverCategory.topluluk:
        return 'Editör ve topluluk listeleri';
    }
  }

  IconData get icon {
    switch (this) {
      case DiscoverCategory.yeniCikanlar:
        return Icons.new_releases_rounded;
      case DiscoverCategory.trendler:
        return Icons.local_fire_department_rounded;
      case DiscoverCategory.top10:
        return Icons.looks_one_rounded;
      case DiscoverCategory.top50:
        return Icons.bar_chart_rounded;
      case DiscoverCategory.topluluk:
        return Icons.groups_rounded;
    }
  }
}

class DiscoverItem {
  const DiscoverItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    this.duration = Duration.zero,
    this.type = DiscoverItemType.song,
    this.playlistId,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final Duration duration;
  final DiscoverItemType type;
  final String? playlistId;
}

enum DiscoverItemType { song, playlist }

class DiscoverService {
  DiscoverService._();

  static Future<List<DiscoverItem>> fetch(DiscoverCategory category,
      {int limit = 20}) async {
    switch (category) {
      case DiscoverCategory.yeniCikanlar:
        return _appleSongs('recent-releases', limit);
      case DiscoverCategory.trendler:
        return _deezerChartTracks(50);
      case DiscoverCategory.top10:
        return _deezerChartTracks(10);
      case DiscoverCategory.top50:
        return _deezerChartTracks(50);
      case DiscoverCategory.topluluk:
        return _deezerChartPlaylists(limit);
    }
  }

  static Future<List<DiscoverItem>> _deezerChartTracks(int limit) async {
    try {
      final resp = await http
          .get(Uri.parse('https://api.deezer.com/chart/0/tracks?limit=$limit'))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tracks = (data['data'] as List?) ?? [];
      return tracks.map((t) {
        final artist = (t['artist']?['name'] as String?) ?? '';
        final album = (t['album']?['title'] as String?) ?? '';
        final duration = Duration(seconds: (t['duration'] as int?) ?? 0);
        final pic = (t['album']?['cover_medium'] as String?) ??
            (t['artist']?['picture_medium'] as String?);
        return DiscoverItem(
          id: '${t['id']}',
          title: (t['title'] as String?) ?? '',
          artist: artist,
          thumbnailUrl: pic,
          duration: duration,
          type: DiscoverItemType.song,
        );
      }).toList();
    } catch (e) {
      debugPrint('Discover deezer chart error: $e');
      return [];
    }
  }

  static Future<List<DiscoverItem>> _deezerChartPlaylists(int limit) async {
    try {
      final resp = await http
          .get(
              Uri.parse('https://api.deezer.com/chart/0/playlists?limit=$limit'))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final lists = (data['data'] as List?) ?? [];
      return lists.map((p) {
        return DiscoverItem(
          id: '${p['id']}',
          title: (p['title'] as String?) ?? '',
          artist: (p['creator']?['name'] as String?) ?? 'Deezer',
          thumbnailUrl: (p['picture_medium'] as String?) ??
              (p['picture'] as String?),
          type: DiscoverItemType.playlist,
          playlistId: '${p['id']}',
        );
      }).toList();
    } catch (e) {
      debugPrint('Discover deezer playlists error: $e');
      return [];
    }
  }

  static Future<List<DiscoverItem>> _appleSongs(String kind, int limit) async {
    try {
      final url =
          'https://rss.applemarketingtools.com/api/v2/us/music/$kind/$limit/songs.json';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (data['feed']?['results'] as List?) ?? [];
      return results.map((r) {
        final artwork = (r['artworkUrl100'] as String?)?.replaceAll(
          '100x100',
          '300x300',
        );
        return DiscoverItem(
          id: '${r['id']}',
          title: (r['name'] as String?) ?? '',
          artist: (r['artistName'] as String?) ?? '',
          thumbnailUrl: artwork,
          type: DiscoverItemType.song,
        );
      }).toList();
    } catch (e) {
      debugPrint('Discover apple rss error: $e');
      return [];
    }
  }

  static Future<List<DiscoverItem>> playlistTracks(String deezerId) async {
    try {
      final resp = await http
          .get(Uri.parse(
              'https://api.deezer.com/playlist/$deezerId/tracks?limit=100'))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tracks = (data['data'] as List?) ?? [];
      return tracks.map((t) {
        final title = (t['title'] as String?) ?? '';
        final artist = (t['artist']?['name'] as String?) ?? '';
        final album = (t['album']?['title'] as String?) ?? '';
        final duration = Duration(seconds: (t['duration'] as int?) ?? 0);
        final pic = (t['album']?['cover_medium'] as String?) ??
            (t['artist']?['picture_medium'] as String?);
        return DiscoverItem(
          id: '$deezerId-${t['id']}',
          title: title,
          artist: artist,
          album: album,
          thumbnailUrl: pic,
          duration: duration,
          type: DiscoverItemType.song,
        );
      }).toList();
    } catch (e) {
      debugPrint('Discover playlist tracks error: $e');
      return [];
    }
  }
}
