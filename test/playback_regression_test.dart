import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/audio_handler.dart';
import 'package:melodi/services/youtube_audio_source.dart';

void main() {
  group('YouTube audio byte ranges', () {
    test('uses an exclusive end and emits the correct HTTP header', () {
      final range = AudioByteRange.normalize(
        totalBytes: 1000,
        start: 125,
        endExclusive: 400,
      );

      expect(range.start, 125);
      expect(range.endExclusive, 400);
      expect(range.length, 275);
      expect(range.httpHeader, 'bytes=125-399');
    });

    test('clamps invalid player requests to the media bounds', () {
      final range = AudioByteRange.normalize(
        totalBytes: 1000,
        start: 1500,
        endExclusive: 2000,
      );

      expect(range.start, 999);
      expect(range.endExclusive, 1000);
      expect(range.length, 1);
    });
  });

  group('queue completion', () {
    test('advances to the next queue item', () {
      final decision = PlaybackCompletionDecision.decide(
        currentIndex: 0,
        queueLength: 2,
        repeatMode: LoopStyle.off,
      );

      expect(decision.action, PlaybackCompletionAction.playIndex);
      expect(decision.nextIndex, 1);
    });

    test('rewinds at the end when repeat is off', () {
      final decision = PlaybackCompletionDecision.decide(
        currentIndex: 1,
        queueLength: 2,
        repeatMode: LoopStyle.off,
      );

      expect(decision.action, PlaybackCompletionAction.rewindAndPause);
      expect(decision.nextIndex, isNull);
    });

    test('wraps the queue when repeat all is enabled', () {
      final decision = PlaybackCompletionDecision.decide(
        currentIndex: 1,
        queueLength: 2,
        repeatMode: LoopStyle.all,
      );

      expect(decision.action, PlaybackCompletionAction.playIndex);
      expect(decision.nextIndex, 0);
    });

    test('replays the same item when repeat one is enabled', () {
      final decision = PlaybackCompletionDecision.decide(
        currentIndex: 0,
        queueLength: 2,
        repeatMode: LoopStyle.one,
      );

      expect(decision.action, PlaybackCompletionAction.replayCurrent);
    });
  });
}
