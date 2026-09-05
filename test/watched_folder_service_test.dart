import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/watched_folder_service.dart';

void main() {
  test('watched folders are polled every five seconds', () {
    expect(WatchedFolderService.scanInterval, const Duration(seconds: 5));
  });
}
