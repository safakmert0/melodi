import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/spotify_service.dart';
import 'package:melodi/utils/spotify_track_mapper.dart';

void main() {
  const track = SpotifyTrackItem(
    id: 'track-42',
    name: 'Test Song',
    artists: ['Artist A', 'Artist B'],
    albumName: 'Test Album',
    albumId: 'album-7',
    albumImageUrl: 'https://example.com/art.jpg',
    durationMs: 183000,
    uri: 'spotify:track:track-42',
  );

  test('Spotify track becomes a resolvable player queue song', () {
    final song = SpotifyTrackMapper.toSong(track);

    expect(song.id, 'spotify:track-42');
    expect(song.filePath, 'spotify://track-42');
    expect(song.title, 'Test Song');
    expect(song.artist, 'Artist A, Artist B');
    expect(song.album, 'Test Album');
    expect(song.duration, const Duration(seconds: 183));
  });

  test('Spotify track keeps download metadata', () {
    final download = SpotifyTrackMapper.toDownload(track);

    expect(download, {
      'id': 'track-42',
      'title': 'Test Song',
      'artist': 'Artist A, Artist B',
      'durationMs': '183000',
      'album': 'Test Album',
      'imageUrl': 'https://example.com/art.jpg',
    });
  });

  test('playlist count can be hydrated without losing metadata', () {
    const playlist = SpotifyPlaylistItem(
      id: 'playlist-1',
      name: 'Road Trip',
      ownerId: 'owner',
      imageUrl: 'https://example.com/playlist.jpg',
    );

    final hydrated = playlist.copyWith(trackCount: 27);

    expect(hydrated.id, playlist.id);
    expect(hydrated.name, playlist.name);
    expect(hydrated.ownerId, playlist.ownerId);
    expect(hydrated.imageUrl, playlist.imageUrl);
    expect(hydrated.trackCount, 27);
  });
}
