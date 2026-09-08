import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/music_source.dart';

void main() {
  group('Music source playback capabilities', () {
    test('youtube is full track and not preview', () {
      expect(MusicSourceType.youtube.supportsFullTrack, isTrue);
      expect(MusicSourceType.youtube.isPreviewCatalogue, isFalse);
    });
  });
}
