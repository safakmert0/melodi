import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// YouTube (googlevideo) kisitlamasina karsi paralel indirme.
///
/// YouTube, `n` parametresi cozulmemis akis URL'lerini baglanti basina
/// ~50-100 KB/s hizina kisar. Tek baglantiyle 5-15 MB'lik bir parca
/// dakikalar surer ve zaman asimlarina takilir. Ayni kisit her baglantiya
/// ayri uygulandigi icin dosyayi N parcaya bolup eszamanli indirmek
/// toplam hizi yaklasik N katina cikarir (tipik: 6 baglanti, ~10-20 sn).
///
/// Sunucu Range desteklemiyorsa otomatikman tek baglantiya duser.
class ParallelDownloader {
  ParallelDownloader._();

  static const String defaultUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  static const int _minChunkSize = 256 * 1024;
  static const int _maxConnections = 8;

  /// Dosyayi indirir, basarida [outputPath]'i dondurur, olmazsa null.
  ///
  /// Ara dosyalar `<outputPath>.part` ve `<outputPath>.part.<i>` adlarini
  /// kullanir; basarisizlikta/iptalde temizlenir.
  ///
  /// [stallTimeout]/[minStallBytes]: verim bekcisi. Bu surede bu kadar
  /// bayttan az veri akan parca oldurulur (damlayan kisitli baglantida
  /// `Stream.timeout` sifirlanir, indirme sonsuza dek %X'te takilir).
  static Future<String?> download({
    required String url,
    required String outputPath,
    Map<String, String> headers = const {},
    int connections = 6,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(minutes: 5),
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    final path = outputPath.trim();
    if (path.isEmpty) return null;

    final mergedHeaders = Map<String, String>.from(headers);
    mergedHeaders.putIfAbsent(
        HttpHeaders.userAgentHeader, () => defaultUserAgent);

    try {
      return await _run(
        uri: uri,
        path: path,
        headers: mergedHeaders,
        connections: connections.clamp(1, _maxConnections),
        onProgress: onProgress,
        isCancelled: isCancelled,
        stallTimeout: stallTimeout,
        minStallBytes: minStallBytes,
      ).timeout(timeout, onTimeout: () {
        debugPrint('ParallelDownloader: zaman aşımı ($url)');
        return null;
      });
    } on TimeoutException catch (e) {
      debugPrint('ParallelDownloader timeout: $e');
      return null;
    } catch (e) {
      debugPrint('ParallelDownloader error: $e');
      return null;
    }
  }

  static Future<String?> _run({
    required Uri uri,
    required String path,
    required Map<String, String> headers,
    required int connections,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    final partPath = '$path.part';
    final partFile = File(partPath);
    try {
      if (await partFile.exists()) await partFile.delete();
    } catch (_) {}

    // 1. Kapa: tek baytlik Range ile toplam boyut + Range destegini ogren.
    final probe = await _probe(uri, headers);
    if (probe == null) return null;
    if (isCancelled != null && isCancelled()) return null;

    final total = probe.totalBytes;
    if (!probe.rangesSupported || total <= 0) {
      // Range yok: klasik tek baglanti.
      return _singleConnection(
        uri: uri,
        path: path,
        headers: headers,
        total: total > 0 ? total : null,
        onProgress: onProgress,
        isCancelled: isCancelled,
        stallTimeout: stallTimeout,
        minStallBytes: minStallBytes,
      );
    }

    // 2. Parcala: her parca en az 256 KB olacak sekilde baglanti sayisini ayarla.
    var n = connections;
    while (n > 1 && total ~/ n < _minChunkSize) {
      n--;
    }
    if (total < _minChunkSize * 2) {
      return _singleConnection(
        uri: uri,
        path: path,
        headers: headers,
        total: total,
        onProgress: onProgress,
        isCancelled: isCancelled,
        stallTimeout: stallTimeout,
        minStallBytes: minStallBytes,
      );
    }

    final chunkSize = total ~/ n;
    var received = 0;
    void report() => onProgress?.call(received, total);

    final futures = <Future<bool>>[];
    for (var i = 0; i < n; i++) {
      final start = i * chunkSize;
      final end = (i == n - 1) ? total - 1 : (start + chunkSize - 1);
      futures.add(_fetchChunk(
        uri: uri,
        headers: headers,
        tmpPath: '$partPath.$i',
        start: start,
        end: end,
        onBytes: (count) {
          received += count;
          report();
        },
        isCancelled: isCancelled,
        stallTimeout: stallTimeout,
        minStallBytes: minStallBytes,
      ));
    }
    final results = await Future.wait(futures);
    if (results.any((ok) => !ok)) {
      await _cleanup(partPath, n);
      return null;
    }
    if (isCancelled != null && isCancelled()) {
      await _cleanup(partPath, n);
      return null;
    }

    // 3. Birlestir ve dogrula.
    try {
      final out = await File(partPath).open(mode: FileMode.write);
      try {
        for (var i = 0; i < n; i++) {
          final chunk = File('$partPath.$i');
          await for (final data in chunk.openRead()) {
            out.writeFromSync(data);
          }
        }
        await out.flush();
      } finally {
        await out.close();
      }
      final len = await File(partPath).length();
      if (len != total) {
        debugPrint('ParallelDownloader: eksik dosya ($len/$total)');
        await _cleanup(partPath, n);
        return null;
      }
      await File(partPath).rename(path);
      for (var i = 0; i < n; i++) {
        try {
          await File('$partPath.$i').delete();
        } catch (_) {}
      }
      onProgress?.call(total, total);
      return path;
    } catch (e) {
      debugPrint('ParallelDownloader merge error: $e');
      await _cleanup(partPath, n);
      return null;
    }
  }

  /// Range destegi ve toplam boyut sondasi.
  static Future<({bool rangesSupported, int totalBytes})?> _probe(
    Uri uri,
    Map<String, String> headers,
  ) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      headers.forEach(req.headers.set);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      // Gövdeyi tüket ki bağlantı havuzu kirlenmesin.
      try {
        await resp.drain<void>();
      } catch (_) {}
      if (resp.statusCode == 206) {
        final cr = resp.headers.value(HttpHeaders.contentRangeHeader) ?? '';
        final total = _parseTotal(cr) ?? resp.contentLength;
        return (rangesSupported: true, totalBytes: total);
      }
      if (resp.statusCode == 200) {
        return (
          rangesSupported: false,
          totalBytes: resp.contentLength > 0 ? resp.contentLength : -1
        );
      }
      debugPrint('ParallelDownloader probe HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ParallelDownloader probe error: $e');
      return null;
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  static int? _parseTotal(String contentRange) {
    // Örn: "bytes 0-0/123456"
    final slash = contentRange.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(contentRange.substring(slash + 1).trim());
  }

  /// Tek parcayi indir (1 otomatik tekrarli).
  ///
  /// Damlayan baglanti korumasi: [stallTimeout] surede [minStallBytes]'tan
  /// az veri gelirse parca iptal edilir. `Stream.timeout` her veri
  /// olayinda sifirlandigi icin yavas ama olu baglantiyi yakalayamaz;
  /// bu bekci ilerlemeyi olcer.
  static Future<bool> _fetchChunk({
    required Uri uri,
    required Map<String, String> headers,
    required String tmpPath,
    required int start,
    required int end,
    required void Function(int count) onBytes,
    bool Function()? isCancelled,
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (isCancelled != null && isCancelled()) return false;
      HttpClient? client;
      try {
        debugPrint('ParallelDownloader chunk $start-$end deneme ${attempt + 1}');
        final file = File(tmpPath);
        if (attempt > 0 && await file.exists()) await file.delete();
        client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final req = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 15));
        headers.forEach(req.headers.set);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 206) {
          debugPrint(
              'ParallelDownloader chunk $start-$end HTTP ${resp.statusCode}');
          continue;
        }
        final sink = file.openWrite(mode: FileMode.write);
        var got = 0;
        final want = end - start + 1;
        // Son anlamli veri zamani: damlama 45 sn'de 32 KB altindaysa olu.
        var windowStart = DateTime.now();
        var windowBytes = 0;
        var stalled = false;
        StreamSubscription<List<int>>? sub;
        final done = Completer<void>();
        Object? streamError;
        try {
          sub = resp.listen(
            (data) {
              if (stalled) return;
              sink.add(data);
              got += data.length;
              windowBytes += data.length;
              onBytes(data.length);
              final now = DateTime.now();
              if (now.difference(windowStart) >= stallTimeout) {
                if (windowBytes < minStallBytes) {
                  stalled = true;
                  debugPrint('ParallelDownloader chunk $start-$end '
                      'takildi (${windowBytes}B/${stallTimeout.inSeconds}sn)');
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
            onError: (Object e) {
              streamError = e;
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
          await done.future.timeout(
            Duration(seconds: stallTimeout.inSeconds * 4 + 120),
            onTimeout: () {
              debugPrint(
                  'ParallelDownloader chunk $start-$end genel zamanasimi');
              sub?.cancel();
            },
          );
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (stalled) continue;
        if (streamError != null) {
          debugPrint(
              'ParallelDownloader chunk $start-$end hata: $streamError');
          continue;
        }
        if (isCancelled != null && isCancelled()) return false;
        if (got == want) return true;
        debugPrint(
            'ParallelDownloader chunk $start-$end eksik ($got/$want)');
      } catch (e) {
        debugPrint('ParallelDownloader chunk $start-$end hata: $e');
      } finally {
        try {
          client?.close(force: true);
        } catch (_) {}
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    return false;
  }

  /// Range yoksa / kucuk dosyada klasik tek baglanti.
  /// Damlayan baglanti bekcisi aynen gecerlidir.
  static Future<String?> _singleConnection({
    required Uri uri,
    required String path,
    required Map<String, String> headers,
    required int? total,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    final partPath = '$path.part';
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final req = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      headers.forEach(req.headers.set);
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('ParallelDownloader single HTTP ${resp.statusCode}');
        return null;
      }
      final expected = (total != null && total > 0)
          ? total
          : (resp.contentLength > 0 ? resp.contentLength : null);
      final sink =
          File(partPath).openWrite(mode: FileMode.write);
      var received = 0;
      var windowStart = DateTime.now();
      var windowBytes = 0;
      var stalled = false;
      StreamSubscription<List<int>>? sub;
      final done = Completer<void>();
      try {
        sub = resp.listen(
          (data) {
            if (stalled) return;
            sink.add(data);
            received += data.length;
            windowBytes += data.length;
            onProgress?.call(received, expected);
            final now = DateTime.now();
            if (now.difference(windowStart) >= stallTimeout) {
              if (windowBytes < minStallBytes) {
                stalled = true;
                debugPrint('ParallelDownloader single takildi '
                    '(${windowBytes}B/${stallTimeout.inSeconds}sn)');
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
          Duration(seconds: stallTimeout.inSeconds * 4 + 180),
          onTimeout: () => sub?.cancel(),
        );
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (stalled) {
        try {
          if (await File(partPath).exists()) {
            await File(partPath).delete();
          }
        } catch (_) {}
        return null;
      }
      if (isCancelled != null && isCancelled()) return null;
      final len = await File(partPath).length();
      if (len < 1000) {
        try {
          await File(partPath).delete();
        } catch (_) {}
        return null;
      }
      if (expected != null && len + 1024 < expected) {
        debugPrint('ParallelDownloader single eksik ($len/$expected)');
        return null;
      }
      await File(partPath).rename(path);
      return path;
    } catch (e) {
      debugPrint('ParallelDownloader single error: $e');
      return null;
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  static Future<void> _cleanup(String partPath, int n) async {
    try {
      if (await File(partPath).exists()) await File(partPath).delete();
    } catch (_) {}
    for (var i = 0; i < n; i++) {
      try {
        final f = File('$partPath.$i');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
