import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/music_source.dart';

void main() {
  group('Music source playback capabilities', () {
    test('preview catalogues cannot be treated as full tracks', () {
      expect(MusicSourceType.deezer.isPreviewCatalogue, isTrue);
      expect(MusicSourceType.deezer.supportsFullTrack, isFalse);
      expect(MusicSourceType.lastfm.supportsFullTrack, isFalse);
    });

    test('full-track resolvers remain playable', () {
      expect(MusicSourceType.youtube.supportsFullTrack, isTrue);
      expect(MusicSourceType.jiosaavn.supportsFullTrack, isTrue);
    });
  });
}
