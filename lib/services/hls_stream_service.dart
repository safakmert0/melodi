import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// HLS (m3u8) hattı: iOS AVPlayer'ın ana dili.
///
/// Neden HLS? Asamali (progressive) googlevideo URL'leri `n` parametresi
/// cozulmedikce YouTube tarafindan baglanti basina ~50-100 KB/s'ye
/// kisilir. HLS segment dagitimi bu kisitlamaya pratikte takilmaz:
/// - Calma: AVPlayer m3u8'i native acar; acilis ve seek aninda olur.
/// - Indirme: onlarca kucuk segment paralel cekilir, toplam hiz yuksektir.
/// fMP4 (init + .m4s) listeler birebir birlestirilip temiz .m4a olur;
/// .ts listeler donusturme gerektirdigi icin atlanip asamali yedege
/// birakilir.
class HlsStreamService {
  HlsStreamService._();
  static final HlsStreamService _instance = HlsStreamService._();
  factory HlsStreamService() => _instance;
  static HlsStreamService get instance => _instance;

  static const int _poolSize = 6;

  /// Manifest HLS listesinden en uygun ses URL'i:
  /// AAC ses > en yuksek bitrate'li ses > ilk HLS girdisi.
  /// (HlsStreamInfo mixin'i public export'ta yok; StreamInfo kullanilir.)
  static String? pickHlsUrl(List<StreamInfo> streams) {
    if (streams.isEmpty) return null;
    HlsAudioStreamInfo? bestAac;
    HlsAudioStreamInfo? bestAudio;
    for (final s in streams) {
      if (s is! HlsAudioStreamInfo) continue;
      final codec = s.audioCodec.toLowerCase();
      if (codec.contains('mp4a') || codec.contains('aac')) {
        if (bestAac == null ||
            s.bitrate.bitsPerSecond > bestAac.bitrate.bitsPerSecond) {
          bestAac = s;
        }
      }
      if (bestAudio == null ||
          s.bitrate.bitsPerSecond > bestAudio.bitrate.bitsPerSecond) {
        bestAudio = s;
      }
    }
    final pick = bestAac ?? bestAudio ?? streams.first;
    final url = pick.url.toString();
    return (url.isNotEmpty && url.startsWith('http')) ? url : null;
  }

  /// Master playlist coz: varyant listesi dondur (bos degilse master'dir).
  static List<HlsVariant> parseMasterPlaylist(String body, Uri base) {
    final variants = <HlsVariant>[];
    final lines = body.split('\n').map((l) => l.trim()).toList();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      final attrs = _parseAttrs(line.substring('#EXT-X-STREAM-INF:'.length));
      var j = i + 1;
      while (j < lines.length &&
          (lines[j].isEmpty || lines[j].startsWith('#'))) {
        j++;
      }
      if (j >= lines.length) break;
      final uri = base.resolve(lines[j]);
      variants.add(HlsVariant(
        uri: uri,
        bandwidth: int.tryParse(attrs['BANDWIDTH'] ?? '') ?? 0,
        codecs: (attrs['CODECS'] ?? '').toLowerCase(),
      ));
      i = j;
    }
    return variants;
  }

  /// Master'dan ses varyanti sec: video codec'i olmayan (saf ses) ve
  /// mp4a iceren en yuksek bant genisligi; olmazsa en yuksek bant.
  static Uri? pickVariant(List<HlsVariant> variants) {
    if (variants.isEmpty) return null;
    const videoCodecs = ['avc1', 'hvc1', 'hev1', 'vp09', 'av01'];
    HlsVariant? best;
    for (final v in variants) {
      final hasVideo = videoCodecs.any(v.codecs.contains);
      final hasAudio =
          v.codecs.contains('mp4a') || v.codecs.contains('aac');
      if (hasVideo || !hasAudio) continue;
      if (best == null || v.bandwidth > best.bandwidth) best = v;
    }
    if (best != null) return best.uri;
    variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return variants.first.uri;
  }

  /// Media playlist coz: init (EXT-X-MAP) + segment URL'leri.
  static HlsMediaPlaylist parseMediaPlaylist(String body, Uri base) {
    Uri? init;
    final segments = <Uri>[];
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-MAP')) {
        final m = RegExp(r'URI="([^"]+)"').firstMatch(line);
        if (m != null) init = base.resolve(m.group(1)!);
        continue;
      }
      if (line.startsWith('#')) continue;
      segments.add(base.resolve(line));
    }
    final first = init?.toString() ??
        (segments.isNotEmpty ? segments.first.toString() : '');
    final lower = first.toLowerCase().split('?').first;
    final isFmp4 = init != null ||
        lower.endsWith('.m4s') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.cmfv') ||
        lower.endsWith('.cmfa');
    return HlsMediaPlaylist(init: init, segments: segments, isFmp4: isFmp4);
  }

  static Map<String, String> _parseAttrs(String s) {
    final out = <String, String>{};
    final re = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)');
    for (final m in re.allMatches(s)) {
      var v = m.group(2) ?? '';
      if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
        v = v.substring(1, v.length - 1);
      }
      out[m.group(1)!] = v;
    }
    return out;
  }

  /// HLS playlistten .m4a indirir. fMP4 degilse (.ts vb.) null doner;
  /// cagiran asamali yedege duser.
  Future<String?> downloadHlsToM4a({
    required String playlistUrl,
    required String outputPath,
    Map<String, String> headers = const {},
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(minutes: 6),
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    final startUri = Uri.tryParse(playlistUrl.trim());
    var path = outputPath.trim();
    if (startUri == null ||
        !(startUri.scheme == 'http' || startUri.scheme == 'https') ||
        path.isEmpty) {
      return null;
    }
    if (!path.toLowerCase().endsWith('.m4a')) {
      if (RegExp(r'\.[A-Za-z0-9]{1,5}$').hasMatch(path)) {
        path = path.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '.m4a');
      } else {
        path = '$path.m4a';
      }
    }
    try {
      return await _run(
        startUri: startUri,
        path: path,
        headers: headers,
        onProgress: onProgress,
        isCancelled: isCancelled,
        stallTimeout: stallTimeout,
        minStallBytes: minStallBytes,
      ).timeout(timeout, onTimeout: () {
        debugPrint('HlsStreamService: zaman aşımı');
        return null;
      });
    } catch (e) {
      debugPrint('HlsStreamService error: $e');
      return null;
    }
  }

  Future<String?> _run({
    required Uri startUri,
    required String path,
    required Map<String, String> headers,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    final merged = Map<String, String>.from(headers);
    merged.putIfAbsent(HttpHeaders.userAgentHeader,
        () => ParallelDownloadUserAgent.value);

    // 1. Playlisti cek: master ise ses varyantina in.
    var body = await _getText(startUri, merged);
    if (body == null) return null;
    if (isCancelled != null && isCancelled()) return null;
    Uri mediaUri = startUri;
    if (body.contains('#EXT-X-STREAM-INF')) {
      final variant =
          pickVariant(parseMasterPlaylist(body, startUri));
      if (variant == null) return null;
      mediaUri = variant;
      body = await _getText(mediaUri, merged);
      if (body == null) return null;
    }
    if (isCancelled != null && isCancelled()) return null;

    // 2. Segment listesi.
    final media = parseMediaPlaylist(body, mediaUri);
    if (media.segments.isEmpty) {
      debugPrint('HlsStreamService: segment yok');
      return null;
    }
    if (!media.isFmp4) {
      // .ts vb: donusturme gerektirir, asamali yedege birak.
      debugPrint('HlsStreamService: fMP4 degil, atlaniyor');
      return null;
    }

    // 3. Init + segmentleri havuzla paralel cek.
    final parts = <Uri>[];
    if (media.init != null) parts.add(media.init!);
    parts.addAll(media.segments);
    final total = parts.length;
    var done = 0;
    final results = List<List<int>?>.filled(total, null);
    var index = 0;
    var failed = false;
    Future<void> worker() async {
      while (true) {
        if (failed) return;
        final i = index++;
        if (i >= total) return;
        if (isCancelled != null && isCancelled()) {
          failed = true;
          return;
        }
        final bytes = await _getBytes(parts[i], merged,
            stallTimeout: stallTimeout, minStallBytes: minStallBytes);
        if (bytes == null || bytes.isEmpty) {
          failed = true;
          return;
        }
        results[i] = bytes;
        done++;
        onProgress?.call(done, total);
      }
    }
    await Future.wait(
        List.generate(min(_poolSize, total), (_) => worker()));
    if (failed || results.any((b) => b == null)) return null;
    if (isCancelled != null && isCancelled()) return null;

    // 4. Sirali birlestir.
    final partPath = '$path.part';
    try {
      final out = await File(partPath).open(mode: FileMode.write);
      try {
        for (final b in results) {
          out.writeFromSync(b!);
        }
        await out.flush();
      } finally {
        await out.close();
      }
      final len = await File(partPath).length();
      if (len < 1000) {
        try {
          await File(partPath).delete();
        } catch (_) {}
        return null;
      }
      await File(partPath).rename(path);
      onProgress?.call(total, total);
      return path;
    } catch (e) {
      debugPrint('HlsStreamService merge error: $e');
      try {
        if (await File(partPath).exists()) {
          await File(partPath).delete();
        }
      } catch (_) {}
      return null;
    }
  }

  Future<String?> _getText(Uri uri, Map<String, String> headers) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final req =
          await client.getUrl(uri).timeout(const Duration(seconds: 15));
      headers.forEach(req.headers.set);
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('HlsStreamService playlist HTTP ${resp.statusCode}');
        return null;
      }
      final body = await resp.transform(utf8.decoder).join().timeout(
          const Duration(seconds: 30));
      return body.isEmpty ? null : body;
    } catch (e) {
      debugPrint('HlsStreamService playlist error: $e');
      return null;
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  Future<List<int>?> _getBytes(
    Uri uri,
    Map<String, String> headers, {
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final req =
            await client.getUrl(uri).timeout(const Duration(seconds: 15));
        headers.forEach(req.headers.set);
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) continue;
        final bytes = <int>[];
        var windowStart = DateTime.now();
        var windowBytes = 0;
        var stalled = false;
        StreamSubscription<List<int>>? sub;
        final done = Completer<void>();
        try {
          sub = resp.listen(
            (chunk) {
              if (stalled) return;
              bytes.addAll(chunk);
              windowBytes += chunk.length;
              final now = DateTime.now();
              if (now.difference(windowStart) >= stallTimeout) {
                if (windowBytes < minStallBytes) {
                  stalled = true;
                  sub?.cancel();
                  if (!done.isCompleted) done.complete();
                } else {
                  windowStart = now;
                  windowBytes = 0;
                }
              }
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            onError: (_) {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
          await done.future.timeout(
            Duration(seconds: stallTimeout.inSeconds * 4 + 60),
            onTimeout: () => sub?.cancel(),
          );
        } finally {
          // ignore: avoid-ignoring-return-values
          sub?.cancel();
        }
        if (stalled) {
          debugPrint('HlsStreamService segment takildi: $uri');
          continue;
        }
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {
        await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)));
      } finally {
        try {
          client?.close(force: true);
        } catch (_) {}
      }
    }
    return null;
  }
}

/// Paralel indiriciyle ayni UA (googlevideo tutarliligi icin tek elden).
class ParallelDownloadUserAgent {
  static const value =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
}

class HlsVariant {
  final Uri uri;
  final int bandwidth;
  final String codecs;
  HlsVariant({required this.uri, required this.bandwidth, required this.codecs});
}

class HlsMediaPlaylist {
  final Uri? init;
  final List<Uri> segments;
  final bool isFmp4;
  HlsMediaPlaylist(
      {required this.init, required this.segments, required this.isFmp4});
}
