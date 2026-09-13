import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/parallel_downloader.dart';

/// Range destekleyen / desteklemeyen sahte HTTP sunuculariyla
/// [ParallelDownloader] davranis testleri (ag gerektirmez).
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('melodi_pdl_test');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('ParallelDownloader', () {
    test('paralel indirir ve icerigi birebir birlestirir', () async {
      final data = _randomBytes(3 * 1024 * 1024);
      final server = await _rangeServer(data, supportRange: true);
      try {
        final out = '${tmp.path}/song.m4a';
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/file',
          outputPath: out,
          connections: 6,
          timeout: const Duration(seconds: 30),
        );
        expect(result, out);
        final file = File(out);
        expect(await file.exists(), isTrue);
        expect(await file.length(), data.length);
        expect(await file.readAsBytes(), orderedEquals(data));
        // Ara dosyalar temizlenmis olmali.
        expect(await Directory(tmp.path).list().length, 1);
      } finally {
        await server.close(force: true);
      }
    });

    test('Range yoksa tek baglantiya duser', () async {
      final data = _randomBytes(300 * 1024);
      final server = await _rangeServer(data, supportRange: false);
      try {
        final out = '${tmp.path}/song.m4a';
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/file',
          outputPath: out,
          timeout: const Duration(seconds: 30),
        );
        expect(result, out);
        expect(await File(out).readAsBytes(), orderedEquals(data));
      } finally {
        await server.close(force: true);
      }
    });

    test('kucuk dosyayi tek baglantiyla indirir', () async {
      final data = _randomBytes(100 * 1024);
      final server = await _rangeServer(data, supportRange: true);
      try {
        final out = '${tmp.path}/small.m4a';
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/file',
          outputPath: out,
          connections: 6,
          timeout: const Duration(seconds: 30),
        );
        expect(result, out);
        expect(await File(out).readAsBytes(), orderedEquals(data));
      } finally {
        await server.close(force: true);
      }
    });

    test('404 icin null doner', () async {
      final server = await _rangeServer(<int>[], supportRange: true);
      try {
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/yok',
          outputPath: '${tmp.path}/nope.m4a',
          timeout: const Duration(seconds: 15),
        );
        expect(result, isNull);
      } finally {
        await server.close(force: true);
      }
    });

    test('iptalde null doner ve parca birakmaz', () async {
      final data = _randomBytes(4 * 1024 * 1024);
      final server = await _rangeServer(data, supportRange: true);
      try {
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/file',
          outputPath: '${tmp.path}/cancel.m4a',
          connections: 6,
          isCancelled: () => true,
          timeout: const Duration(seconds: 30),
        );
        expect(result, isNull);
        expect(await File('${tmp.path}/cancel.m4a').exists(), isFalse);
      } finally {
        await server.close(force: true);
      }
    });

    test('gecersiz URL icin null doner', () async {
      expect(
        await ParallelDownloader.download(
          url: 'youtube://abc123',
          outputPath: '${tmp.path}/x.m4a',
        ),
        isNull,
      );
    });

    test('damlayan baglantiyi bekci oldurur (takilip kalmaz)', () async {
      // Her 1 sn'de 1 KB: Stream.timeout sifirlanir ama verim bekcisi
      // (3 sn / 64 KB) takilmayi yakalamalidir.
      final server = await _dripServer(
          totalBytes: 600 * 1024, every: const Duration(seconds: 1));
      try {
        final sw = Stopwatch()..start();
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/file',
          outputPath: '${tmp.path}/drip.m4a',
          connections: 2,
          stallTimeout: const Duration(seconds: 3),
          minStallBytes: 64 * 1024,
          timeout: const Duration(seconds: 60),
        );
        sw.stop();
        expect(result, isNull);
        // Bekci ~3-10 sn'de oldurmeli; 60 sn cap'e takilmamali.
        expect(sw.elapsed.inSeconds, lessThan(45));
      } finally {
        await server.close(force: true);
      }
    });

    test('damlayan tek baglantiyi bekci oldurur', () async {
      final server = await _dripServer(
          totalBytes: 300 * 1024, every: const Duration(seconds: 1));
      try {
        final sw = Stopwatch()..start();
        final result = await ParallelDownloader.download(
          url: 'http://127.0.0.1:${server.port}/file',
          outputPath: '${tmp.path}/drip_single.m4a',
          connections: 2,
          stallTimeout: const Duration(seconds: 3),
          minStallBytes: 64 * 1024,
          timeout: const Duration(seconds: 60),
        );
        sw.stop();
        expect(result, isNull);
        expect(sw.elapsed.inSeconds, lessThan(45));
      } finally {
        await server.close(force: true);
      }
    });
  });
}

List<int> _randomBytes(int length) {
  final rnd = Random(42);
  return List<int>.generate(length, (_) => rnd.nextInt(256));
}

/// Damlayan sunucu: Range'i destekler ama veriyi cok yavas damlatir
/// (kisitlanmis googlevideo taklidi).
Future<HttpServer> _dripServer(
    {required int totalBytes, required Duration every}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    try {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      var start = 0;
      var end = totalBytes - 1;
      var partial = false;
      if (range != null) {
        final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
        if (m != null) {
          if (m.group(1)!.isNotEmpty) start = int.parse(m.group(1)!);
          if (m.group(2)!.isNotEmpty) end = int.parse(m.group(2)!);
          partial = true;
        }
      }
      if (partial) {
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-$end/$totalBytes');
      }
      req.response.headers.contentLength = end - start + 1;
      const drip = 1024;
      var sent = start;
      while (sent <= end) {
        final n = (end - sent + 1).clamp(0, drip);
        req.response.add(List<int>.filled(n, 0xAB));
        await req.response.flush();
        sent += n;
        if (sent <= end) await Future<void>.delayed(every);
      }
      await req.response.close();
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  });
  return server;
}

/// Basit dosya sunucusu: istenirse Range (206) destekler.
Future<HttpServer> _rangeServer(List<int> data,
    {required bool supportRange}) async {
  final server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    try {
      if (req.uri.path != '/file') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (supportRange && range != null) {
        final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
        var start = 0;
        var end = data.length - 1;
        if (m != null) {
          if (m.group(1)!.isNotEmpty) start = int.parse(m.group(1)!);
          if (m.group(2)!.isNotEmpty) end = int.parse(m.group(2)!);
        }
        start = start.clamp(0, data.length);
        end = end.clamp(-1, data.length - 1);
        if (start > end || data.isEmpty) {
          req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await req.response.close();
          return;
        }
        final body = data.sublist(start, end + 1);
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(
            HttpHeaders.contentRangeHeader, 'bytes $start-$end/${data.length}');
        req.response.headers.contentLength = body.length;
        req.response.add(body);
        await req.response.close();
        return;
      }
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentLength = data.length;
      req.response.add(data);
      await req.response.close();
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  });
  return server;
}
