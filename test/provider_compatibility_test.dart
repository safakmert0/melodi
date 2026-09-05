import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/models/extension.dart';

void main() {
  test('SpotiFLAC registry provider roles and network permissions are kept',
      () {
    final entry = RegistryEntry.fromJson({
      'id': 'lyrics-provider',
      'name': 'Lyrics Provider',
      'download_url': 'https://example.test/provider.sflx',
      'type': ['lyrics_provider', 'metadata_provider'],
      'capabilities': ['lyrics', 'metadata'],
      'permissions': {
        'network': ['api.example.test', '*.cdn.example.test'],
      },
    });

    expect(entry, isNotNull);
    expect(entry!.capabilities, containsAll(['lyrics', 'metadata']));
    expect(entry.permissions,
        containsAll(['api.example.test', '*.cdn.example.test']));
    expect(entry.category, contains('lyrics_provider'));
  });

  test('installed extension preserves provider capabilities', () {
    final manifest = ExtensionManifest(
      id: 'download-provider',
      name: 'Download Provider',
      description: 'test',
      version: '1.0.0',
      author: 'test',
      kind: ExtensionKind.hifi,
      baseUrl: 'https://example.test',
      homepage: 'https://example.test/provider.sflx',
      capabilities: const ['playback', 'downloads', 'lossless'],
      permissions: const ['api.example.test'],
    );
    final restored = InstalledExtension.fromJson({
      'manifest': manifest.toJson(),
      'enabled': true,
      'installedAt': '2026-01-01T00:00:00Z',
    });

    expect(restored.manifest.capabilities, contains('downloads'));
    expect(restored.manifest.permissions, ['api.example.test']);
  });

  test('signed session contract survives installed-extension persistence', () {
    final manifest = ExtensionManifest.fromJson({
      'id': 'signed-provider',
      'name': 'Signed Provider',
      'version': '2.0.0',
      'author': 'test',
      'kind': 'hifi',
      'baseUrl': 'https://example.test',
      'permissions': {
        'network': ['api.example.test'],
      },
      'requiredRuntimeFeatures': ['signedSession@3', 'sessionGrant@1'],
      'signedSession': {
        'baseUrl': 'https://api.example.test/v2',
        'appVersion': 'provider@2.0.0',
        'callbackUrl': 'spotiflac://session-grant',
        'endpoints': {'bootstrap': '/bootstrap'},
      },
    });
    final restored = ExtensionManifest.fromJson(manifest.toJson());

    expect(restored.permissions, ['api.example.test']);
    expect(restored.requiredRuntimeFeatures, contains('signedSession@3'));
    expect(restored.signedSession?['appVersion'], 'provider@2.0.0');
  });
}
