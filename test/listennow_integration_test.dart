import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/models/source_descriptor.dart';
import 'package:melodi/services/download_manager.dart';
import 'package:melodi/services/music_source.dart';
import 'package:melodi/services/navidrome_service.dart';
import 'package:melodi/services/source_catalog.dart';

void main() {
  group('Navidrome personal library integration', () {
    test('normalizes a Subsonic server root without exposing /rest twice', () {
      expect(
        NavidromeService.normalizeServerUrl(
          ' https://music.example.com/rest/ ',
        ),
        'https://music.example.com',
      );
    });

    test('rejects insecure or malformed server addresses', () {
      expect(
        () => NavidromeService.normalizeServerUrl('http://music.example.com'),
        throwsFormatException,
      );
      expect(
        () => NavidromeService.normalizeServerUrl('music.example.com'),
        throwsFormatException,
      );
    });

    test('catalog advertises connected full-track offline capabilities', () {
      final source = SourceCatalog.build(
        spotifyConnected: false,
        youtubeMusicConnected: false,
        navidromeConnected: true,
      ).firstWhere((item) => item.kind == SourceKind.navidrome);

      expect(source.status, SourceStatus.connected);
      expect(source.isReady, isTrue);
      expect(source.supports(SourceCapability.playback), isTrue);
      expect(source.supports(SourceCapability.downloads), isTrue);
      expect(source.supports(SourceCapability.lossless), isTrue);
      expect(MusicSourceType.navidrome.supportsFullTrack, isTrue);
    });

    test('download tasks retain their exact personal-server URL', () {
      const directUrl =
          'https://music.example.com/rest/download.view?id=track-1';
      final task = DownloadTask(
        id: 'task-1',
        spotifyTrackId: 'navidrome:track-1',
        directUrl: directUrl,
        title: 'Song',
        artist: 'Artist',
      );

      expect(task.directUrl, directUrl);
    });
  });
}
