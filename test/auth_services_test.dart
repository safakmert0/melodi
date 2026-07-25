import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/spotify_service.dart';
import 'package:melodi/services/ytmusic_service.dart';

class _FakeInnerTubeClient extends InnerTubeClient {
  _FakeInnerTubeClient(this.response);

  final Map<String, dynamic>? response;

  @override
  Future<Map<String, dynamic>?> browse(String browseId) async => response;
}

void main() {
  group('SpotifyService session lifecycle', () {
    test('disconnect clears the in-memory account session', () {
      final service = SpotifyService();
      service.restoreSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAtEpoch: 4102444800,
        username: 'listener',
        clientId: 'client-id',
      );

      expect(service.isConnected, isTrue);

      service.disconnect();

      expect(service.isConnected, isFalse);
      expect(service.accessToken, isNull);
      expect(service.refreshToken, isNull);
      expect(service.username, isNull);
    });
  });

  group('YTMusicService authentication', () {
    test('rejects cookies without a SAPISID credential', () {
      final service = YTMusicService();

      expect(service.connectWithCookie('PREF=language=tr'), isFalse);
      expect(service.isConnected, isFalse);
    });

    test('accepts a structurally valid cookie after a successful probe',
        () async {
      final service = YTMusicService(
        client: _FakeInnerTubeClient(<String, dynamic>{'contents': {}}),
      );

      expect(service.connectWithCookie('SAPISID=test-secret'), isTrue);
      expect(await service.validateConnection(), isTrue);
      expect(service.isConnected, isTrue);
    });

    test('clears the session when the authenticated probe fails', () async {
      final service = YTMusicService(client: _FakeInnerTubeClient(null));

      expect(service.connectWithCookie('SAPISID=test-secret'), isTrue);
      expect(await service.validateConnection(), isFalse);
      expect(service.isConnected, isFalse);
      expect(service.cookie, isNull);
    });
  });
}
