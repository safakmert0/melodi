import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FFmpegRingtoneService {
  static const MethodChannel _channel = MethodChannel('com.melodi/ffmpeg_ringtone');

  /// Extract audio from a video file
  /// Returns the path to the extracted audio file
  static Future<String?> extractAudio({
    required String inputPath,
    String? outputPath,
    double startTime = 0,
    double duration = 30,
    String outputFormat = 'm4a',
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final output = outputPath ??
          '${dir.path}/extracted_${DateTime.now().millisecondsSinceEpoch}.$outputFormat';

      final result = await _channel.invokeMethod('extractAudio', {
        'inputPath': inputPath,
        'outputPath': output,
        'startTime': startTime,
        'duration': duration,
        'outputFormat': outputFormat,
      });

      if (result != null && result['outputPath'] != null) {
        return result['outputPath'] as String;
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('FFmpeg extractAudio error: ${e.message}');
      return null;
    }
  }

  /// Get video duration in seconds
  static Future<double?> getVideoDuration(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('getVideoDuration', {
        'videoPath': videoPath,
      });
      if (result != null && result['duration'] != null) {
        return (result['duration'] as num).toDouble();
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('FFmpeg getVideoDuration error: ${e.message}');
      return null;
    }
  }

  /// Save an audio file as a ringtone (iOS)
  /// Returns the path to the .m4r ringtone file
  /// Note: On iOS, the file is saved to Documents and must be shared via Share Sheet
  /// for the user to save it as a ringtone in Settings
  static Future<RingtoneResult?> saveAsRingtone({
    required String audioPath,
    required String ringtoneName,
    double startTime = 0,
    double duration = 30,
  }) async {
    try {
      final result = await _channel.invokeMethod('saveAsRingtone', {
        'audioPath': audioPath,
        'ringtoneName': ringtoneName,
        'startTime': startTime,
        'duration': duration,
      });

      if (result != null && result['ringtonePath'] != null) {
        return RingtoneResult(
          ringtonePath: result['ringtonePath'] as String,
          duration: (result['duration'] as num).toDouble(),
          name: result['name'] as String,
        );
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('FFmpeg saveAsRingtone error: ${e.message}');
      return null;
    }
  }

  /// Extract audio from video and save as ringtone in one step
  static Future<RingtoneResult?> extractAndSaveAsRingtone({
    required String videoPath,
    required String ringtoneName,
    double startTime = 0,
    double duration = 30,
  }) async {
    final audioPath = await extractAudio(
      inputPath: videoPath,
      startTime: startTime,
      duration: duration,
    );

    if (audioPath == null) return null;

    return saveAsRingtone(
      audioPath: audioPath,
      ringtoneName: ringtoneName,
      startTime: 0,
      duration: duration,
    );
  }

  /// Share the ringtone file so user can save it to iOS ringtones
  /// This opens the iOS Share Sheet with the .m4r file
  static Future<void> shareRingtone(RingtoneResult ringtone) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(ringtone.ringtonePath)],
          text: 'Ringtone: ${ringtone.name}',
          subject: ringtone.name,
        ),
      );
    } catch (e) {
      debugPrint('Share ringtone error: $e');
    }
  }
}

class RingtoneResult {
  final String ringtonePath;
  final double duration;
  final String name;

  RingtoneResult({
    required this.ringtonePath,
    required this.duration,
    required this.name,
  });
}