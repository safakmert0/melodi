import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LoudnessResult {
  final double integratedLoudness;
  final double truePeak;
  final double loudnessRange;

  const LoudnessResult({
    required this.integratedLoudness,
    required this.truePeak,
    required this.loudnessRange,
  });

  Map<String, dynamic> toMap() => {
        'integratedLoudness': integratedLoudness,
        'truePeak': truePeak,
        'loudnessRange': loudnessRange,
      };
}

class LoudnessService {
  LoudnessService._();

  static Future<LoudnessResult?> measureLoudness(String audioPath) async {
    try {
      final process = await Process.start('ffmpeg', [
        '-i',
        audioPath,
        '-af',
        'loudnorm=I=-23:LRA=7:TP=-1:print_format=json',
        '-f',
        'null',
        '-',
      ]);

      final stderrBytes = <int>[];
      process.stderr.listen((chunk) => stderrBytes.addAll(chunk));
      await process.exitCode;

      final stderr = utf8.decode(stderrBytes);
      final jsonStart = stderr.indexOf('{');
      final jsonEnd = stderr.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
        return await _fallbackLoudness(audioPath);
      }

      final jsonStr = stderr.substring(jsonStart, jsonEnd + 1);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return LoudnessResult(
        integratedLoudness:
            double.tryParse(data['input_i']?.toString() ?? '') ?? 0,
        truePeak: double.tryParse(data['input_tp']?.toString() ?? '') ?? 0,
        loudnessRange:
            double.tryParse(data['input_lra']?.toString() ?? '') ?? 0,
      );
    } catch (e) {
      debugPrint('measureLoudness failed: $e');
      return await _fallbackLoudness(audioPath);
    }
  }

  static Future<LoudnessResult?> _fallbackLoudness(String audioPath) async {
    try {
      final process = await Process.start('ffprobe', [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        audioPath,
      ]);

      final stdoutBytes = <int>[];
      process.stdout.listen((chunk) => stdoutBytes.addAll(chunk));
      await process.exitCode;

      final stdout = utf8.decode(stdoutBytes);
      final data = jsonDecode(stdout) as Map<String, dynamic>;
      final format = data['format'] as Map<String, dynamic>?;

      return LoudnessResult(
        integratedLoudness: 0,
        truePeak: 0,
        loudnessRange: 0,
      );
    } catch (e) {
      debugPrint('_fallbackLoudness failed: $e');
      return null;
    }
  }

  static Future<String> normalizeLoudness(
    String inputPath,
    String outputPath, {
    double targetLufs = -14.0,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final measured = await measureLoudness(inputPath);
      double offset = targetLufs;

      if (measured != null && measured.integratedLoudness != 0) {
        offset = targetLufs - measured.integratedLoudness;
      }

      final process = await Process.start('ffmpeg', [
        '-i',
        inputPath,
        '-af',
        'loudnorm=I=${targetLufs.toStringAsFixed(1)}:LRA=7:TP=-1.5:measured_I=${measured?.integratedLoudness.toStringAsFixed(1) ?? targetLufs.toStringAsFixed(1)}:measured_LRA=${measured?.loudnessRange.toStringAsFixed(1) ?? '7'}:measured_TP=${measured?.truePeak.toStringAsFixed(2) ?? '-1.5'}:measured_thresh=-30:offset=${offset.toStringAsFixed(1)}:linear=true:print_format=summary',
        '-c:a',
        'flac',
        '-compression_level',
        '8',
        '-y',
        outputPath,
      ]);

      final stderrBytes = <int>[];
      process.stderr.listen((chunk) {
        stderrBytes.addAll(chunk);
        if (onProgress != null) {
          onProgress(0.5);
        }
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        debugPrint('normalizeLoudness ffmpeg exit: $exitCode');
        await File(inputPath).copy(outputPath);
      }

      return outputPath;
    } catch (e) {
      debugPrint('normalizeLoudness failed: $e');
      await File(inputPath).copy(outputPath);
      return outputPath;
    }
  }

  static Future<void> addReplayGainTags(
    String audioPath, {
    double? albumPeak,
  }) async {
    try {
      if (audioPath.endsWith('.flac')) {
        await Process.run('metaflac', [
          '--remove-all-tags',
          '--add-replay-gain',
          audioPath,
        ]);
      } else {
        await Process.run('ffmpeg', [
          '-i',
          audioPath,
          '-af',
          'replaygain',
          '-f',
          'null',
          '-',
        ]);
      }
    } catch (e) {
      debugPrint('addReplayGainTags failed: $e');
    }
  }
}
