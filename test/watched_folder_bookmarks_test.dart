import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/watched_folder_bookmarks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.melodi/watched_folders');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('WatchedFolderBookmarks', () {
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('pickFolder yolu döndürür', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickFolder');
        return {'path': '/private/var/mobile/Music', 'name': 'Music'};
      });
      final picked = await WatchedFolderBookmarks.pickFolder();
      expect(picked.path, '/private/var/mobile/Music');
      expect(picked.icloudRejected, isFalse);
    });

    test('pickFolder iptalde null döndürür', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final picked = await WatchedFolderBookmarks.pickFolder();
      expect(picked.path, isNull);
      expect(picked.icloudRejected, isFalse);
    });

    test('pickFolder iCloud reddini işaretler', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'icloud_not_supported');
      });
      final picked = await WatchedFolderBookmarks.pickFolder();
      expect(picked.path, isNull);
      expect(picked.icloudRejected, isTrue);
    });

    test('resolveFolders yolları tekilleştirir', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return {
          'folders': [
            {'key': '/a', 'path': '/a'},
            {'key': '/a', 'path': '/a'},
            {'key': '/b', 'path': '/b'},
          ]
        };
      });
      expect(await WatchedFolderBookmarks.resolveFolders(), ['/a', '/b']);
    });

    test('removeFolder ve clearFolders sessiz tamamlanır', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => true);
      await WatchedFolderBookmarks.removeFolder('/a');
      await WatchedFolderBookmarks.clearFolders();
    });
  });
}
