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

  group('queue failure fallback', () {
    test('tries each following item once without wrapping when repeat is off',
        () {
      final candidates = PlaybackFailurePlan.candidateIndices(
        currentIndex: 0,
        queueLength: 4,
        repeatMode: LoopStyle.off,
      );

      expect(candidates, [1, 2, 3]);
    });

    test('does not retry the failed final item', () {
      final candidates = PlaybackFailurePlan.candidateIndices(
        currentIndex: 2,
        queueLength: 3,
        repeatMode: LoopStyle.off,
      );

      expect(candidates, isEmpty);
    });

    test('wraps once without revisiting the failed item for repeat all', () {
      final candidates = PlaybackFailurePlan.candidateIndices(
        currentIndex: 2,
        queueLength: 4,
        repeatMode: LoopStyle.all,
      );

      expect(candidates, [3, 0, 1]);
      expect(candidates.toSet().length, candidates.length);
      expect(candidates, isNot(contains(2)));
    });

    test('a single failed item has no fallback candidate', () {
      final candidates = PlaybackFailurePlan.candidateIndices(
        currentIndex: 0,
        queueLength: 1,
        repeatMode: LoopStyle.all,
      );

      expect(candidates, isEmpty);
    });
  });
}
