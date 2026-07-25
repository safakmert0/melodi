import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/models/source_descriptor.dart';
import 'package:melodi/services/source_catalog.dart';

void main() {
  test('local source is always ready and supports offline lossless playback',
      () {
    final sources = SourceCatalog.build(
      spotifyConnected: false,
      youtubeMusicConnected: false,
    );
    final local =
        sources.firstWhere((source) => source.kind == SourceKind.local);

    expect(local.isReady, isTrue);
    expect(local.supports(SourceCapability.playback), isTrue);
    expect(local.supports(SourceCapability.downloads), isTrue);
    expect(local.supports(SourceCapability.lossless), isTrue);
  });

  test('account sources expose expired state before disconnected state', () {
    final sources = SourceCatalog.build(
      spotifyConnected: true,
      spotifyExpired: true,
      youtubeMusicConnected: true,
    );
    final spotify =
        sources.firstWhere((source) => source.kind == SourceKind.spotify);
    final youtubeMusic =
        sources.firstWhere((source) => source.kind == SourceKind.youtubeMusic);

    expect(spotify.status, SourceStatus.expired);
    expect(spotify.isReady, isFalse);
    expect(youtubeMusic.status, SourceStatus.connected);
    expect(youtubeMusic.isReady, isTrue);
  });
}
