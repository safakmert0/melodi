import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// JollyTone cok katmanli hat birebir:
/// `yt_audio_stream` + `stream_client` karsiligi.
/// Kutuphane yonetimli manifest (androidSdkless: PO Token istemez;
/// bos donerse otomatik tv yedegi), imza cozme, HLS destegi ve
/// iOS uyumu icin mp4 (m4a) tercihli en yuksek bitrate secimi.
class ExplodeStreamService {
  ExplodeStreamService._();
  static final ExplodeStreamService _instance = ExplodeStreamService._();
  factory ExplodeStreamService() => _instance;
  static ExplodeStreamService get instance => _instance;

  final YoutubeExplode _yt = YoutubeExplode();

  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  Map<String, String> get streamHeaders => {'User-Agent': _userAgent};

  Future<AudioOnlyStreamInfo?> _pickAudio(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) return null;
    // Istemciyi kutuphaneye birak: varsayilan androidSdkless PO Token
    // istemez; bos donerse kutuphane otomatik tv ile tekrar dener.
    // (safari/androidVr acikca gecilirse tv yedegi devre disi kalir.)
    final manifest = await _yt.videos.streams
        .getManifest(id)
        .timeout(const Duration(seconds: 30));
    final audios = manifest.audioOnly.toList();
    if (audios.isEmpty) return null;
    // iOS (just_audio/AVPlayer) mp4/m4a ister; once mp4 icinden en buyugu,
    // yoksa genel en yuksek bitrate (JollyTone withHighestBitrate).
    AudioOnlyStreamInfo? bestMp4;
    AudioOnlyStreamInfo? biggest;
    for (final a in audios) {
      if (biggest == null || a.size.totalBytes > biggest.size.totalBytes) {
        biggest = a;
      }
      if (a.container.name.toLowerCase().contains('mp4')) {
        if (bestMp4 == null ||
            a.size.totalBytes > bestMp4.size.totalBytes) {
          bestMp4 = a;
        }
      }
    }
    return bestMp4 ?? biggest ?? manifest.audioOnly.withHighestBitrate();
  }

  /// Dogrudan calinabilir akis URL'i (just_audio AudioSource.uri ile).
  /// Dosya indirmeden streaming calis — JollyTone hizi buradan gelir.
  Future<String?> getStreamUrl(String videoId) async {
    try {
      final info = await _pickAudio(videoId);
      final url = info?.url.toString() ?? '';
      if (url.isEmpty || !url.startsWith('http')) return null;
      return url;
    } catch (e) {
      debugPrint('Explode stream error: $e');
      return null;
    }
  }

  /// Gercek dosya indirme (byte pipe + ilerleme + iptal).
  /// Donus: dosya yolu veya null.
  Future<String?> downloadToFile({
    required String videoId,
    required String outputPath,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      final info = await _pickAudio(videoId);
      if (info == null) return null;
      var path = outputPath.trim();
      if (path.isEmpty) return null;
      final ext = info.container.name.toLowerCase().contains('mp4')
          ? '.m4a'
          : '.opus';
      if (!path.toLowerCase().endsWith(ext)) {
        if (RegExp(r'\.[A-Za-z0-9]{1,5}$').hasMatch(path)) {
          path = path.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), ext);
        } else {
          path = '$path$ext';
        }
      }
      final file = File(path);
      await file.parent.create(recursive: true);
      final stream = _yt.videos.streams.get(info);
      final sink = file.openWrite(mode: FileMode.write);
      var received = 0;
      final total = info.size.totalBytes;
      try {
        await for (final chunk
            in stream.timeout(const Duration(seconds: 120))) {
          if (isCancelled != null && isCancelled()) {
            throw const FileSystemException('cancelled');
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total > 0 ? total : null);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final len = await file.length();
      if (len < 1000) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      return path;
    } on TimeoutException catch (e) {
      debugPrint('Explode download timeout: $e');
      return null;
    } catch (e) {
      debugPrint('Explode download error: $e');
      return null;
    }
  }
}
