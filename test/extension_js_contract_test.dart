import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/models/extension.dart';
import 'package:melodi/services/sources/extension_source.dart';

InstalledExtension _ext({
  required String id,
  required String homepage,
  ExtensionKind kind = ExtensionKind.backend,
}) {
  return InstalledExtension(
    manifest: ExtensionManifest(
      id: id,
      name: id,
      description: '',
      version: '1.0.0',
      author: 'zarzet',
      kind: kind,
      baseUrl: 'https://localhost',
      homepage: homepage,
    ),
    installedAt: DateTime(2026),
  );
}

void main() {
  test('SpotiFLAC .sflx paketi JS paketi sayılır', () {
    final src = ExtensionMusicSource(_ext(
      id: 'ytmusic-spotiflac',
      homepage:
          'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/ytmusic-spotiflac.sflx',
    ));
    expect(src.isJsBundle, isTrue);
    expect(src.bundleUrl.endsWith('.sflx'), isTrue);
  });

  test('8spine .8spine paketi JS paketi sayılır', () {
    final src = ExtensionMusicSource(_ext(
      id: 'loki-mog',
      homepage: 'https://8spine-modules.vercel.app/modules/loki-mog.8spine',
    ));
    expect(src.isJsBundle, isTrue);
  });

  test('Düz backend manifesti JS paketi sayılmaz', () {
    final src = ExtensionMusicSource(_ext(
      id: 'melodi.public-ytdlp',
      homepage: 'https://github.com/safakmert0/melodi-extensions',
    ));
    expect(src.isJsBundle, isFalse);
  });

  test('Eklenti türü korunur (hifi/backend)', () {
    final hifi = ExtensionMusicSource(_ext(
      id: 'qobuz-web',
      homepage: 'https://example.com/qobuz-web.sflx',
      kind: ExtensionKind.hifi,
    ));
    expect(hifi.type.name, 'hifi');
  });
}
