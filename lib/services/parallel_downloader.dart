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
  /// Ara dosyalar `<outputPath>.part`, `<outputPath>.part.<i>` ve
  /// `<outputPath>.meta` adlarini kullanir. Basarisiz/iptal durumunda
  /// parcalar SAKLANIR; ayni URL+boyut+baglanti sayisiyla tekrar
  /// cagrildiginda kalan kisimdan devam edilir (kaldigi yerden surdurme).
  /// Icerik degismisse (meta uyusmazligi) temiz baslanir.
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

  /// URL+toplam+baglanti icin kararli meta anahtari (calismalar arasi).
  /// Dart String.hashCode calisma basina degisir, o yuzden FNV-1a.
  static int _metaHash(String url, int total, int n) {
    var h = 0x811c9dc5;
    final s = '$url|$total|$n';
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
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

    // Kaldigi yerden surdurme: meta uyusuyorsa bitmis/eksik parcalari kullan.
    final metaFile = File('$partPath.meta');
    var resumable = false;
    try {
      if (await metaFile.exists()) {
        final meta = (await metaFile.readAsString()).trim().split(':');
        if (meta.length == 3 &&
            int.tryParse(meta[0]) == total &&
            int.tryParse(meta[1]) == n &&
            int.tryParse(meta[2]) == _metaHash(uri.toString(), total, n)) {
          resumable = true;
        }
      }
    } catch (_) {
      resumable = false;
    }
    if (!resumable) {
      // Farkli baglanti sayisindan kalma parcalar icin tum olasiliklari sil.
      await _cleanup(partPath, _maxConnections);
    }
    try {
      await metaFile.writeAsString('$total:$n:${_metaHash(uri.toString(), total, n)}');
    } catch (_) {}
    final resumeFrom = List<int>.filled(n, 0);
    if (resumable) {
      for (var i = 0; i < n; i++) {
        final start = i * chunkSize;
        final end = (i == n - 1) ? total - 1 : (start + chunkSize - 1);
        final want = end - start + 1;
        try {
          final f = File('$partPath.$i');
          if (await f.exists()) {
            final len = await f.length();
            if (len >= want) {
              resumeFrom[i] = want;
              received += want;
            } else if (len > 0) {
              resumeFrom[i] = len;
              received += len;
            } else {
              try {
                await f.delete();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
      if (received > 0) {
        debugPrint('ParallelDownloader: $received/$total bayt hazir, devam ediliyor');
        report();
      }
    }

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
        resumeFrom: resumeFrom[i],
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
      // Parcalar saklanir; sonraki deneme kaldigi yerden surer.
      return null;
    }
    if (isCancelled != null && isCancelled()) {
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
        // Birlesmis hatali cikti silinir, parcalar saklanir (devam icin).
        try {
          await File(partPath).delete();
        } catch (_) {}
        return null;
      }
      await File(partPath).rename(path);
      for (var i = 0; i < n; i++) {
        try {
          await File('$partPath.$i').delete();
        } catch (_) {}
      }
      try {
        await File('$partPath.meta').delete();
      } catch (_) {}
      onProgress?.call(total, total);
      return path;
    } catch (e) {
      debugPrint('ParallelDownloader merge error: $e');
      try {
        await File(partPath).delete();
      } catch (_) {}
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
  /// [resumeFrom]: parcadaki hazir bayt sayisi; istek `start+resumeFrom`'dan
  /// baslar ve dosya uzerine eklenir. Hazir kisim tamamsa indirmeden doner.
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
    int resumeFrom = 0,
    required void Function(int count) onBytes,
    bool Function()? isCancelled,
    Duration stallTimeout = const Duration(seconds: 45),
    int minStallBytes = 32 * 1024,
  }) async {
    final want = end - start + 1;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (isCancelled != null && isCancelled()) return false;
      HttpClient? client;
      try {
        final file = File(tmpPath);
        // Tekrar denemede dosyadaki gercek durumdan devam et (ekleme kipi).
        var offset = resumeFrom;
        if (attempt > 0 || offset > 0) {
          try {
            final len = await file.exists() ? await file.length() : 0;
            if (len >= want) return true;
            if (len > offset) offset = len;
          } catch (_) {}
        }
        if (offset >= want) return true;
        final reqStart = start + offset;
        if (offset > 0) {
          debugPrint('ParallelDownloader chunk $start-$end '
              'kaldigi yerden ($reqStart)');
        } else {
          debugPrint('ParallelDownloader chunk $start-$end deneme ${attempt + 1}');
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
        client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final req = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 15));
        headers.forEach(req.headers.set);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$reqStart-$end');
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 206) {
          debugPrint(
              'ParallelDownloader chunk $start-$end HTTP ${resp.statusCode}');
          if (offset > 0) {
            // Sunucu araligi yoksaydi (200/416): ekleme bozmasin diye bastan.
            try {
              await file.delete();
            } catch (_) {}
          }
          continue;
        }
        final sink = file.openWrite(mode: FileMode.append);
        var got = offset;
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
