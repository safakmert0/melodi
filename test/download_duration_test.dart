import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/download_manager.dart';

void main() {
  final manager = DownloadManager();

  test('rejects an eight minute source for a four minute track', () {
    expect(
      manager.isDurationCompatible(
        const Duration(minutes: 8),
        const Duration(minutes: 4).inMilliseconds,
      ),
      isFalse,
    );
  });

  test('accepts small catalogue and container duration differences', () {
    expect(
      manager.isDurationCompatible(
        const Duration(minutes: 4, seconds: 7),
        const Duration(minutes: 4).inMilliseconds,
      ),
      isTrue,
    );
  });

  test('allows unknown durations for backward compatibility', () {
    expect(
      manager.isDurationCompatible(const Duration(minutes: 8), 0),
      isTrue,
    );
  });
}
