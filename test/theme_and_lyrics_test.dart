import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/core/constants.dart';
import 'package:melodi/services/lyrics_service.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  tearDown(() => AppTheme.isLightMode = false);

  test('legacy screens keep readable text contrast in both themes', () {
    AppTheme.isLightMode = true;
    expect(_contrast(MelodiTheme.onSurface, MelodiTheme.background),
        greaterThan(7));
    expect(_contrast(MelodiTheme.onSurfaceVariant, MelodiTheme.background),
        greaterThan(4.5));

    AppTheme.isLightMode = false;
    expect(_contrast(MelodiTheme.onSurface, MelodiTheme.background),
        greaterThan(7));
    expect(_contrast(MelodiTheme.onSurfaceVariant, MelodiTheme.background),
        greaterThan(4.5));
  });

  test('LRC parser preserves ordered synchronized lines', () {
    final lines = LrcParser.parse(
      '[00:12.50]İkinci\n[00:03.250]Birinci\n[00:12.50][00:18.00]Nakarat',
    );

    expect(lines.map((line) => line.timestampMs),
        orderedEquals([3250, 12500, 12500, 18000]));
    expect(lines.first.text, 'Birinci');
    expect(lines.last.text, 'Nakarat');
  });

  test('LRC parser applies the embedded offset tag', () {
    final lines = LrcParser.parse(
      '''[offset:-500]
[00:01.000]Erken
[00:02.000]Sonraki''',
    );

    expect(lines.map((line) => line.timestampMs), orderedEquals([500, 1500]));
  });

  test('lyrics timing scales source duration and applies manual correction',
      () {
    final lyricPosition = LyricsTiming.lyricPositionMs(
      playbackPositionMs: 60000,
      manualOffsetMs: 500,
      playbackDurationMs: 240000,
      lyricsDurationMs: 242000,
    );
    final lines = <LrcLine>[
      const LrcLine(0, 'A'),
      const LrcLine(59000, 'B'),
      const LrcLine(61000, 'C'),
    ];

    expect(lyricPosition, 59996);
    expect(LyricsTiming.findLineIndex(lines, lyricPosition), 1);
    expect(
      LyricsTiming.playbackPositionMs(
        lyricPositionMs: lyricPosition,
        manualOffsetMs: 500,
        playbackDurationMs: 240000,
        lyricsDurationMs: 242000,
      ),
      closeTo(60000, 1),
    );
  });

  test('lyrics seek resolves the target line from the playback timeline', () {
    final lines = [
      const LrcLine(10000, 'first'),
      const LrcLine(60000, 'second'),
      const LrcLine(120000, 'third'),
    ];

    expect(
      LyricsTiming.findLineIndexAtPlayback(
        lines: lines,
        playbackPositionMs: 121000,
        playbackDurationMs: 180000,
        lyricsDurationMs: 180000,
      ),
      2,
    );
    expect(
      LyricsTiming.findLineIndexAtPlayback(
        lines: lines,
        playbackPositionMs: 61000,
        manualOffsetMs: 2000,
        playbackDurationMs: 180000,
        lyricsDurationMs: 180000,
      ),
      0,
    );
  });
}
