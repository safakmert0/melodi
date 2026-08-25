import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'multi_source_search.dart';
import 'music_source.dart';
import 'lastfm_service.dart';
import 'spotify_service.dart';

enum RadioType {
  artist,
  genre,
  mood,
  activity,
  similar,
  discovery,
}

class RadioStation {
  final String id;
  final String name;
  final String description;
  final RadioType type;
  final String? seedId;
  final String? seedType;
  final String? artworkUrl;
  final List<OnlineTrack> tracks;
  final DateTime generatedAt;

  const RadioStation({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.seedId,
    this.seedType,
    this.artworkUrl,
    required this.tracks,
    required this.generatedAt,
  });

  RadioStation copyWith({
    String? id,
    String? name,
    String? description,
    RadioType? type,
    String? seedId,
    String? seedType,
    String? artworkUrl,
    List<OnlineTrack>? tracks,
    DateTime? generatedAt,
  }) {
    return RadioStation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      seedId: seedId ?? this.seedId,
      seedType: seedType ?? this.seedType,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      tracks: tracks ?? this.tracks,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

class RadioService {
  RadioService._();
  static final RadioService _instance = RadioService._();
  factory RadioService() => _instance;
  static RadioService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;
  final MultiSourceSearch _multiSource = MultiSourceSearch();
  final SpotifyService _spotify = SpotifyService();
  final LastFmService _lastFm = LastFmService();

  final Random _random = Random();
  final Map<String, RadioStation> _cache = {};
  final Map<String, int> _stationIndices = {};

  final StreamController<RadioStation?> _currentStationController =
      StreamController<RadioStation?>.broadcast();
  final StreamController<OnlineTrack?> _currentTrackController =
      StreamController<OnlineTrack?>.broadcast();

  Stream<RadioStation?> get currentStationStream => _currentStationController.stream;
  Stream<OnlineTrack?> get currentTrackStream => _currentTrackController.stream;

  RadioStation? _currentStation;
  int _currentTrackIndex = 0;

  RadioStation? get currentStation => _currentStation;
  OnlineTrack? get currentTrack =>
      _currentStation != null && _currentTrackIndex < _currentStation!.tracks.length
          ? _currentStation!.tracks[_currentTrackIndex]
          : null;

  Future<RadioStation> createArtistRadio(String artistName, {int count = 50}) async {
    final cacheKey = 'artist_radio_$artistName';
    if (_cache.containsKey(cacheKey)) {
      final station = _cache[cacheKey]!;
      if (DateTime.now().difference(station.generatedAt).inHours < 24) {
        return station;
      }
    }

    final similarArtists = await _getSimilarArtists(artistName, limit: 20);
    final allTracks = <OnlineTrack>[];

    for (final artist in similarArtists.take(10)) {
      try {
        final tracks = await _multiSource.searchAllSync(
          '${artist} top tracks',
          limitPerSource: 3,
        );
        allTracks.addAll(tracks);
      } catch (_) {}
    }

    allTracks.shuffle(_random);
    final selected = allTracks.take(count).toList();

    final station = RadioStation(
      id: cacheKey,
      name: '$artistName Radio',
      description: '$artistName ve benzer sanatçılar',
      type: RadioType.artist,
      seedId: artistName,
      seedType: 'artist',
      artworkUrl: await _getArtistArtwork(artistName),
      tracks: selected,
      generatedAt: DateTime.now(),
    );

    _cache[cacheKey] = station;
    return station;
  }

  Future<RadioStation> createGenreRadio(String genre, {int count = 50}) async {
    final cacheKey = 'genre_radio_$genre';
    if (_cache.containsKey(cacheKey)) {
      final station = _cache[cacheKey]!;
      if (DateTime.now().difference(station.generatedAt).inHours < 24) {
        return station;
      }
    }

    final topArtists = await _getTopArtistsByGenre(genre, limit: 15);
    final allTracks = <OnlineTrack>[];

    for (final artist in topArtists) {
      try {
        final tracks = await _multiSource.searchAllSync(
          '$artist $genre',
          limitPerSource: 2,
        );
        allTracks.addAll(tracks);
      } catch (_) {}
    }

    allTracks.shuffle(_random);
    final selected = allTracks.take(count).toList();

    final station = RadioStation(
      id: cacheKey,
      name: '$genre Radio',
      description: '$genre türünden en iyi şarkılar',
      type: RadioType.genre,
      seedId: genre,
      seedType: 'genre',
      tracks: selected,
      generatedAt: DateTime.now(),
    );

    _cache[cacheKey] = station;
    return station;
  }

  Future<RadioStation> createMoodRadio(String mood, {int count = 50}) async {
    final moodTags = {
      'happy': ['pop', 'dance', 'funk', 'disco', 'upbeat'],
      'sad': ['slow', 'acoustic', 'piano', 'ambient', 'melancholic'],
      'energetic': ['rock', 'metal', 'electronic', 'edm', 'workout'],
      'chill': ['lofi', 'ambient', 'chillhop', 'downtempo', 'study'],
      'focus': ['instrumental', 'classical', 'ambient', 'post-rock', 'study'],
      'romantic': ['r&b', 'soul', 'jazz', 'slow jam', 'love songs'],
      'party': ['dance', 'hip-hop', 'pop', 'latin', 'reggaeton'],
    };

    final tags = moodTags[mood.toLowerCase()] ?? [mood];
    final allTracks = <OnlineTrack>[];

    for (final tag in tags.take(5)) {
      try {
        final tracks = await _multiSource.searchAllSync(
          '$tag $mood',
          limitPerSource: 3,
        );
        allTracks.addAll(tracks);
      } catch (_) {}
    }

    allTracks.shuffle(_random);
    final selected = allTracks.take(count).toList();

    final station = RadioStation(
      id: 'mood_radio_$mood',
      name: '$mood Vibes',
      description: '$mood modunda şarkılar',
      type: RadioType.mood,
      seedId: mood,
      seedType: 'mood',
      tracks: selected,
      generatedAt: DateTime.now(),
    );

    _cache['mood_radio_$mood'] = station;
    return station;
  }

  Future<RadioStation> createActivityRadio(String activity, {int count = 50}) async {
    final activityTags = {
      'workout': ['workout', 'gym', 'running', 'motivation', 'energetic'],
      'study': ['study', 'focus', 'concentration', 'lofi', 'ambient'],
      'sleep': ['sleep', 'ambient', 'white noise', 'relaxing', 'calm'],
      'drive': ['road trip', 'driving', 'highway', 'classic rock', 'sing along'],
      'cooking': ['cooking', 'kitchen', 'feel good', 'jazz', 'soul'],
      'coding': ['coding', 'programming', 'focus', 'electronic', 'synthwave'],
    };

    final tags = activityTags[activity.toLowerCase()] ?? [activity];
    final allTracks = <OnlineTrack>[];

    for (final tag in tags.take(5)) {
      try {
        final tracks = await _multiSource.searchAllSync(
          '$tag music',
          limitPerSource: 3,
        );
        allTracks.addAll(tracks);
      } catch (_) {}
    }

    allTracks.shuffle(_random);
    final selected = allTracks.take(count).toList();

    final station = RadioStation(
      id: 'activity_radio_$activity',
      name: '$activity Mix',
      description: '$activity için hazırlanmış liste',
      type: RadioType.activity,
      seedId: activity,
      seedType: 'activity',
      tracks: selected,
      generatedAt: DateTime.now(),
    );

    _cache['activity_radio_$activity'] = station;
    return station;
  }

  Future<RadioStation> createSimilarRadio(String trackId, String title, String artist, {int count = 50}) async {
    final cacheKey = 'similar_radio_$trackId';
    if (_cache.containsKey(cacheKey)) {
      final station = _cache[cacheKey]!;
      if (DateTime.now().difference(station.generatedAt).inHours < 12) {
        return station;
      }
    }

    final similarTracks = await _getSimilarTracks(title, artist, limit: 15);
    final allTracks = <OnlineTrack>[];

    for (final similar in similarTracks) {
      try {
        final tracks = await _multiSource.searchAllSync(
          '${similar['artist']} - ${similar['title']}',
          limitPerSource: 2,
        );
        allTracks.addAll(tracks);
      } catch (_) {}
    }

    allTracks.shuffle(_random);
    final selected = allTracks.take(count).toList();

    final station = RadioStation(
      id: cacheKey,
      name: '"$title" Radio',
      description: '$title - $artist ile benzer şarkılar',
      type: RadioType.similar,
      seedId: trackId,
      seedType: 'track',
      tracks: selected,
      generatedAt: DateTime.now(),
    );

    _cache[cacheKey] = station;
    return station;
  }

  Future<RadioStation> createDiscoveryRadio({int count = 50}) async {
    final cacheKey = 'discovery_radio';
    if (_cache.containsKey(cacheKey)) {
      final station = _cache[cacheKey]!;
      if (DateTime.now().difference(station.generatedAt).inHours < 6) {
        return station;
      }
    }

    final userArtists = await _getUserTopArtists(limit: 20);
    final allTracks = <OnlineTrack>[];

    for (final artist in userArtists.take(10)) {
      final similar = await _getSimilarArtists(artist, limit: 5);
      for (final s in similar) {
        try {
          final tracks = await _multiSource.searchAllSync(
            '$s top tracks',
            limitPerSource: 1,
          );
          allTracks.addAll(tracks);
        } catch (_) {}
      }
    }

    allTracks.shuffle(_random);
    final selected = allTracks.take(count).toList();

    final station = RadioStation(
      id: cacheKey,
      name: 'Discovery Weekly',
      description: 'Senin için önerilen yeni şarkılar',
      type: RadioType.discovery,
      seedType: 'user_taste',
      tracks: selected,
      generatedAt: DateTime.now(),
    );

    _cache[cacheKey] = station;
    return station;
  }

  Future<List<String>> _getSimilarArtists(String artist, {int limit = 10}) async {
    try {
      final similar = await _lastFm.getSimilarArtists(artist, limit: limit);
      return similar.map((a) => a['name'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _getTopArtistsByGenre(String genre, {int limit = 15}) async {
    try {
      return await _lastFm.getTopArtistsByTag(genre, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> _getSimilarTracks(String title, String artist, {int limit = 10}) async {
    try {
      return await _lastFm.getSimilarTracks(artist, title, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _getUserTopArtists({int limit = 20}) async {
    try {
      final topArtists = await _db.getTopArtists(limit);
      return topArtists
          .map((a) => a['artist'] as String? ?? '')
          .where((a) => a.isNotEmpty)
          .toList();
    } catch (_) {}
    return [];
  }

  Future<String?> _getArtistArtwork(String artist) async {
    try {
      return await _lastFm.getArtistImage(artist);
    } catch (_) {
      return null;
    }
  }

  void startStation(RadioStation station) {
    _currentStation = station;
    _currentTrackIndex = 0;
    _stationIndices[station.id] = 0;
    _currentStationController.add(station);
    _currentTrackController.add(station.tracks.isNotEmpty ? station.tracks[0] : null);
  }

  OnlineTrack? nextTrack() {
    if (_currentStation == null) return null;
    _currentTrackIndex++;
    if (_currentTrackIndex >= _currentStation!.tracks.length) {
      _currentTrackIndex = 0;
    }
    _stationIndices[_currentStation!.id] = _currentTrackIndex;
    final track = _currentStation!.tracks[_currentTrackIndex];
    _currentTrackController.add(track);
    return track;
  }

  OnlineTrack? previousTrack() {
    if (_currentStation == null) return null;
    _currentTrackIndex--;
    if (_currentTrackIndex < 0) {
      _currentTrackIndex = _currentStation!.tracks.length - 1;
    }
    _stationIndices[_currentStation!.id] = _currentTrackIndex;
    final track = _currentStation!.tracks[_currentTrackIndex];
    _currentTrackController.add(track);
    return track;
  }

  Future<RadioStation?> refreshCurrentStation({int count = 50}) async {
    if (_currentStation == null) return null;

    final newStation = await _regenerateStation(_currentStation!, count);
    _currentStation = newStation;
    _currentTrackIndex = 0;
    _currentStationController.add(newStation);
    _currentTrackController.add(newStation.tracks.isNotEmpty ? newStation.tracks[0] : null);
    return newStation;
  }

  Future<RadioStation> _regenerateStation(RadioStation station, int count) async {
    switch (station.type) {
      case RadioType.artist:
        return createArtistRadio(station.seedId!, count: count);
      case RadioType.genre:
        return createGenreRadio(station.seedId!, count: count);
      case RadioType.mood:
        return createMoodRadio(station.seedId!, count: count);
      case RadioType.activity:
        return createActivityRadio(station.seedId!, count: count);
      case RadioType.similar:
        return createSimilarRadio(station.seedId!, '', '', count: count);
      case RadioType.discovery:
        return createDiscoveryRadio(count: count);
    }
  }

  List<RadioStation> getCachedStations() => _cache.values.toList();

  void clearCache() {
    _cache.clear();
  }

  void dispose() {
    _currentStationController.close();
    _currentTrackController.close();
  }
}