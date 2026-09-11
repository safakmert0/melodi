import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
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

  String? _lastError;

  /// Son cagrinin kisa hata aciklamasi (basarida null).
  String? get lastError => _lastError;

  static String _shortErr(Object e) {
    final s = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  /// Kapsayici adi -> dosya uzantisi. Bilinmeyende orijinal adi koru
  /// (mp3/m4a/flac/opus/webm/3gp ne gelirse).
  static String _extForContainer(String containerName) {
    final n = containerName.toLowerCase().trim();
    if (n.contains('mp4') || n.contains('m4a')) return '.m4a';
    if (n.contains('webm')) return '.opus';
    if (n.contains('3gp')) return '.3gp';
    if (n.contains('mp3')) return '.mp3';
    if (n.contains('flac')) return '.flac';
    if (n.contains('ogg') || n.contains('opus')) return '.opus';
    if (n.contains('wav')) return '.wav';
    final clean = n.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.isNotEmpty && clean.length <= 5) return '.$clean';
    return '.m4a';
  }

  static bool _isHls(AudioOnlyStreamInfo a) {
    final container = a.container.name.toLowerCase();
    if (container.contains('m3u8') || container.contains('hls')) return true;
    final url = a.url.toString().toLowerCase();
    return url.contains('.m3u8');
  }

  static int _score(AudioOnlyStreamInfo a) => a.bitrate.bitsPerSecond > 0
      ? a.bitrate.bitsPerSecond
      : a.size.totalBytes;

  Future<AudioOnlyStreamInfo?> _pickAudio(
    String videoId, {
    bool forDownload = false,
  }) async {
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
    int byBitrate(AudioOnlyStreamInfo a, AudioOnlyStreamInfo b) =>
        _score(b).compareTo(_score(a));
    // Indirme: uzanti fark etmez, ne varsa en yuksek bitrate'li dosya
    // (mp3/m4a/opus/webm). Yalnizca canli-yayin listesi (m3u8) indirilemez.
    if (forDownload) {
      final files = audios.where((a) => !_isHls(a)).toList()..sort(byBitrate);
      if (files.isNotEmpty) return files.first;
      final any = audios.toList()..sort(byBitrate);
      return any.firstOrNull ?? manifest.audioOnly.withHighestBitrate();
    }
    // Akis: HLS listesi just_audio AVPlayer'da acilmaz, elenir.
    // iOS (just_audio/AVPlayer) yalnizca AAC/MP4 calar; opus/webm
    // secti mi yukleme (-1) hatasi verir. Siralama: AAC > mp4 > en yuksek
    // bitrate. totalBytes DEGIL bitrate karsilastirilir (uzun dusuk
    // kalite dosya, kisa yuksek kaliteden buyuk olabilir).
    final playable = audios.where((a) => !_isHls(a)).toList();
    final pool = playable.isNotEmpty ? playable : audios;
    final aac = pool
        .where((a) {
          final codec = a.audioCodec.toLowerCase();
          return codec.contains('mp4a') || codec.contains('aac');
        })
        .toList()
      ..sort(byBitrate);
    if (aac.isNotEmpty) return aac.first;
    final mp4 = pool
        .where((a) => a.container.name.toLowerCase().contains('mp4'))
        .toList()
      ..sort(byBitrate);
    if (mp4.isNotEmpty) return mp4.first;
    pool.sort(byBitrate);
    return pool.firstOrNull ?? manifest.audioOnly.withHighestBitrate();
  }

  /// Dogrudan calinabilir akis URL'i (just_audio AudioSource.uri ile).
  /// Dosya indirmeden streaming calis — JollyTone hizi buradan gelir.
  Future<String?> getStreamUrl(String videoId) async {
    _lastError = null;
    try {
      final info = await _pickAudio(videoId);
      final url = info?.url.toString() ?? '';
      if (url.isEmpty || !url.startsWith('http')) {
        _lastError = 'Akış bulunamadı (manifest boş)';
        return null;
      }
      return url;
    } catch (e) {
      _lastError = _shortErr(e);
      debugPrint('Explode stream error: $e');
      return null;
    }
  }

  /// Cozumlenmis akis (arka plan indiriciye verilir).
  /// Donus null ise [_lastError] sebebi aciklar.
  Future<({String url, Map<String, String> headers, int totalBytes, String ext})?>
      resolveStream(String videoId) async {
    _lastError = null;
    try {
      final info = await _pickAudio(videoId, forDownload: true);
      if (info == null) {
        _lastError = _lastError ?? 'Akış bulunamadı (manifest boş)';
        return null;
      }
      final url = info.url.toString();
      if (url.isEmpty || !url.startsWith('http')) {
        _lastError = 'Akış bulunamadı (manifest boş)';
        return null;
      }
      final ext = _extForContainer(info.container.name);
      return (
        url: url,
        headers: Map<String, String>.from(streamHeaders),
        totalBytes: info.size.totalBytes,
        ext: ext,
      );
    } catch (e) {
      _lastError = _shortErr(e);
      debugPrint('Explode resolve error: $e');
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
    _lastError = null;
    try {
      final info = await _pickAudio(videoId, forDownload: true);
      if (info == null) {
        _lastError = _lastError ?? 'Akış bulunamadı (manifest boş)';
        return null;
      }
      var path = outputPath.trim();
      if (path.isEmpty) return null;
      final ext = _extForContainer(info.container.name);
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
      _lastError = 'Zaman aşımı: ${_shortErr(e)}';
      debugPrint('Explode download timeout: $e');
      return null;
    } catch (e) {
      _lastError = _shortErr(e);
      debugPrint('Explode download error: $e');
      return null;
    }
  }
}
