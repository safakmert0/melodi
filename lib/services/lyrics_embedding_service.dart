import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LyricsEmbeddingService {
  LyricsEmbeddingService._();

  static const MethodChannel _channel =
      MethodChannel('com.melodi/metadata_writer');

  static Future<bool> embedAndNormalize({
    required String filePath,
    String? lyrics,
    int expectedDurationMs = 0,
  }) async {
    if (kIsWeb || !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('embedLyrics', {
            'path': filePath,
            'lyrics': lyrics,
            'expectedDurationMs': expectedDurationMs,
          }) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('Lyrics metadata writer failed: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('Lyrics metadata writer failed: $error');
      return false;
    }
  }
}
