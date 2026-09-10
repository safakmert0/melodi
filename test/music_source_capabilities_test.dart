import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/music_source.dart';

void main() {
  group('Music source playback capabilities', () {
    test('youtube is full track and not preview', () {
      expect(MusicSourceType.youtube.supportsFullTrack, isTrue);
      expect(MusicSourceType.youtube.isPreviewCatalogue, isFalse);
    });

    test('hifi is full track and not preview', () {
      expect(MusicSourceType.hifi.supportsFullTrack, isTrue);
      expect(MusicSourceType.hifi.isPreviewCatalogue, isFalse);
    });
  });

  group('OnlineTrack item type', () {
    OnlineTrack track(String itemType) => OnlineTrack(
          id: 'abcdefghijk',
          title: 'Parça',
          artist: 'Sanatçı',
          source: MusicSourceType.youtube,
          itemType: itemType,
        );

    test('video klipler engelli kabul edilir', () {
      expect(track('video').isVideo, isTrue);
      expect(track('Video').isVideo, isTrue);
    });

    test('müzik sürümleri ve bilinmeyenler engelli sayılmaz', () {
      expect(track('song').isVideo, isFalse);
      expect(track('').isVideo, isFalse);
      expect(track('track').isVideo, isFalse);
    });

    test('copyWith itemType korur', () {
      const base = OnlineTrack(
        id: 'abcdefghijk',
        title: 'Parça',
        artist: 'Sanatçı',
        source: MusicSourceType.youtube,
      );
      expect(base.itemType, isEmpty);
      expect(base.copyWith(itemType: 'song').itemType, 'song');
    });
  });
}
