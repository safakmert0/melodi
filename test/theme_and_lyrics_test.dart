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
}
