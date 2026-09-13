import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_parser/http_parser.dart';
import 'package:melodi/services/hls_stream_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// [HlsStreamService] testleri: secim mantigi, m3u8 cozumu ve
/// localhost sahte sunucuyla uctan uca fMP4 indirme (ag gerektirmez).
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('melodi_hls_test');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  HlsAudioStreamInfo audio({
    required int tag,
    required String codec,
    required int bps,
    String url = 'http://127.0.0.1/x.m3u8',
  }) =>
      HlsAudioStreamInfo(
        VideoId('dQw4w9WgXcQ'),
        tag,
        Uri.parse(url),
        StreamContainer.m3u8,
        FileSize(1000),
        Bitrate(bps),
        codec,
        'medium',
        MediaType('audio', 'mp4'),
      );

  group('pickHlsUrl', () {
    test('AAC sesi opus/webm sesine tercih eder', () {
      final opus = audio(tag: 1, codec: 'opus', bps: 500000);
      final aac = audio(tag: 2, codec: 'mp4a.40.2', bps: 128000);
      expect(HlsStreamService.pickHlsUrl([opus, aac]),
          aac.url.toString());
    });

    test('AAC yoksa en yuksek bitrate sesi secer', () {
      final lo = audio(tag: 1, codec: 'opus', bps: 64000);
      final hi = audio(tag: 2, codec: 'opus', bps: 160000);
      expect(
          HlsStreamService.pickHlsUrl([lo, hi]), hi.url.toString());
    });

    test('bos listede null doner', () {
      expect(HlsStreamService.pickHlsUrl(const []), isNull);
    });
  });

  group('parseMasterPlaylist', () {
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,CODECS="avc1.64001f,mp4a.40.2",RESOLUTION=640x360
video.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"
audio.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=256000,CODECS="opus"
audio-opus.m3u8
''';

    test('varyantlari cozer ve saf sesi secer', () {
      final base = Uri.parse('http://h/video/');
      final variants =
          HlsStreamService.parseMasterPlaylist(master, base);
      expect(variants.length, 3);
      final pick = HlsStreamService.pickVariant(variants);
      expect(pick.toString(), 'http://h/video/audio.m3u8');
    });

    test('saf ses yoksa en yuksek banti secer', () {
      const onlyMuxed = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,CODECS="avc1.64001f,mp4a.40.2"
video.m3u8
''';
      final variants = HlsStreamService.parseMasterPlaylist(
          onlyMuxed, Uri.parse('http://h/'));
      expect(HlsStreamService.pickVariant(variants).toString(),
          'http://h/video.m3u8');
    });
  });

  group('parseMediaPlaylist', () {
    test('init + gorece segmentleri cozer, fMP4 tanir', () {
      const body = '''
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXT-X-MAP:URI="init.mp4"
seg-0.m4s
seg-1.m4s
#EXT-X-ENDLIST
''';
      final pl = HlsStreamService.parseMediaPlaylist(
          body, Uri.parse('http://h/a/list.m3u8'));
      expect(pl.init.toString(), 'http://h/a/init.mp4');
      expect(pl.segments.length, 2);
      expect(pl.segments.first.toString(), 'http://h/a/seg-0.m4s');
      expect(pl.isFmp4, isTrue);
    });

    test('.ts listeyi fMP4 disi sayar', () {
      const body = '''
#EXTM3U
seg-0.ts
seg-1.ts
''';
      final pl = HlsStreamService.parseMediaPlaylist(
          body, Uri.parse('http://h/a/'));
      expect(pl.isFmp4, isFalse);
      expect(pl.segments.length, 2);
    });
  });

  group('downloadHlsToM4a (localhost)', () {
    test('fMP4 listeyi sirayla birlestirir', () async {
      final rnd = Random(7);
      final init = List<int>.generate(512, (_) => rnd.nextInt(256));
      final segs = List.generate(
          4, (_) => List<int>.generate(2048, (_) => rnd.nextInt(256)));
      final server = await _hlsServer(init: init, segments: segs);
      try {
        final out = '${tmp.path}/song.bin';
        final result =
            await HlsStreamService.instance.downloadHlsToM4a(
          playlistUrl: 'http://127.0.0.1:${server.port}/master.m3u8',
          outputPath: out,
          timeout: const Duration(seconds: 30),
        );
        expect(result, isNotNull);
        expect(result!.toLowerCase().endsWith('.m4a'), isTrue);
        final bytes = await File(result).readAsBytes();
        final expected = [...init, for (final s in segs) ...s];
        expect(bytes, orderedEquals(expected));
      } finally {
        await server.close(force: true);
      }
    });

    test('.ts liste icin null doner (asamali yedek sinyali)', () async {
      final server = await _hlsServer(
          init: const [], segments: const [],
          tsMode: true);
      try {
        final result =
            await HlsStreamService.instance.downloadHlsToM4a(
          playlistUrl: 'http://127.0.0.1:${server.port}/ts.m3u8',
          outputPath: '${tmp.path}/song.bin',
          timeout: const Duration(seconds: 30),
        );
        expect(result, isNull);
      } finally {
        await server.close(force: true);
      }
    });

    test('404 playlist icin null doner', () async {
      final server = await _hlsServer(init: const [], segments: const []);
      try {
        final result =
            await HlsStreamService.instance.downloadHlsToM4a(
          playlistUrl: 'http://127.0.0.1:${server.port}/yok.m3u8',
          outputPath: '${tmp.path}/song.bin',
          timeout: const Duration(seconds: 15),
        );
        expect(result, isNull);
      } finally {
        await server.close(force: true);
      }
    });
  });
}

/// Sahte HLS sunucusu: master -> audio varyanti -> fMP4 media.
Future<HttpServer> _hlsServer({
  required List<int> init,
  required List<List<int>> segments,
  bool tsMode = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    try {
      final p = req.uri.path;
      req.response.headers.contentType = ContentType.text;
      if (p == '/master.m3u8') {
        req.response.write('''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,CODECS="avc1.64001f,mp4a.40.2"
video.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"
audio.m3u8
''');
      } else if (p == '/audio.m3u8') {
        final buf = StringBuffer('#EXTM3U\n#EXT-X-TARGETDURATION:6\n'
            '#EXT-X-MAP:URI="init.mp4"\n');
        for (var i = 0; i < segments.length; i++) {
          buf.writeln('seg-$i.m4s');
        }
        buf.writeln('#EXT-X-ENDLIST');
        req.response.write(buf.toString());
      } else if (p == '/init.mp4') {
        req.response.headers.contentType = ContentType.binary;
        req.response.add(init);
      } else if (p.startsWith('/seg-') && p.endsWith('.m4s')) {
        final i = int.parse(
            p.substring('/seg-'.length, p.length - '.m4s'.length));
        req.response.headers.contentType = ContentType.binary;
        req.response.add(segments[i]);
      } else if (p == '/ts.m3u8') {
        req.response.write('#EXTM3U\nseg-0.ts\nseg-1.ts\n#EXT-X-ENDLIST');
      } else {
        req.response.statusCode = HttpStatus.notFound;
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
