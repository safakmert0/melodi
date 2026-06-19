import 'package:open_filex/open_filex.dart';

class FileOpener {
  static Future<void> open(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Failed to open file: ${result.message}');
    }
  }
}
