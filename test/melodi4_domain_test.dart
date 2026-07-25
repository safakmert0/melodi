import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/models/song_model.dart';
import 'package:melodi/services/download_manager.dart';
import 'package:melodi/widgets/library/library_components.dart';

SongModel _song(String id, String path) => SongModel(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      filePath: path,
      fileSize: 1024,
    );

void main() {
  group('Melodi 4 library source filters', () {
    final local = _song('local', r'C:\Music\track.flac');
    final spotify = _song('spotify', 'spotify://track/123');
    final youtube = _song('youtube', 'youtube://video-id');
    final remote = _song('remote', 'https://cdn.example.test/audio.m4a');

    test('all includes every supported song location', () {
      expect(
        [local, spotify, youtube, remote]
            .where(LibrarySourceFilter.all.matches),
        hasLength(4),
      );
    });

    test('device excludes account and expiring stream locations', () {
      expect(LibrarySourceFilter.device.matches(local), isTrue);
      expect(LibrarySourceFilter.device.matches(spotify), isFalse);
      expect(LibrarySourceFilter.device.matches(youtube), isFalse);
      expect(LibrarySourceFilter.device.matches(remote), isFalse);
    });

    test('spotify and youtube scopes remain separate', () {
      expect(LibrarySourceFilter.spotify.matches(spotify), isTrue);
      expect(LibrarySourceFilter.spotify.matches(youtube), isFalse);
      expect(LibrarySourceFilter.youtube.matches(youtube), isTrue);
      expect(LibrarySourceFilter.youtube.matches(remote), isTrue);
    });
  });

  test('download tasks default to the high quality policy', () {
    final task = DownloadTask(
      id: 'task',
      spotifyTrackId: 'track',
      title: 'Track',
      artist: 'Artist',
    );

    expect(task.requestedQuality, 'high');
  });
}
