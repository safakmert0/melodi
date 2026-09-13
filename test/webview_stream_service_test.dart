import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/webview_stream_service.dart';

/// [WebViewStreamService.pickWebAudio] secim mantigi testleri
/// (ag gerektirmez; kopru ciktisi taklit edilir).
void main() {
  Map<String, dynamic> fmt(
          {required int itag,
          required String mime,
          required int br,
          String? url}) =>
      {
        'itag': itag,
        'mime': mime,
        'bitrate': br,
        if (url != null) 'url': url,
      };

  const uAacLo = 'http://g/videoplayback?aac-lo';
  const uAacHi = 'http://g/videoplayback?aac-hi';
  const uOpus = 'http://g/videoplayback?opus';

  group('pickWebAudio', () {
    test('en yuksek bitrate AAC secer', () {
      final got = WebViewStreamService.pickWebAudio({
        'status': 'OK',
        'adaptiveFormats': [
          fmt(itag: 251, mime: 'audio/webm; codecs="opus"', br: 160000, url: uOpus),
          fmt(itag: 139, mime: 'audio/mp4; codecs="mp4a.40.5"', br: 48000, url: uAacLo),
          fmt(itag: 140, mime: 'audio/mp4; codecs="mp4a.40.2"', br: 128000, url: uAacHi),
        ],
      });
      expect(got, isNotNull);
      expect(got!['url'], uAacHi);
      expect(got['ext'], '.m4a');
      expect(got['itag'], 140);
    });

    test('opus-only listede null doner (AVPlayer calamaz)', () {
      final got = WebViewStreamService.pickWebAudio({
        'status': 'OK',
        'adaptiveFormats': [
          fmt(itag: 251, mime: 'audio/webm; codecs="opus"', br: 160000, url: uOpus),
        ],
      });
      expect(got, isNull);
    });

    test('URLsiz (cipher) girdileri atlar', () {
      final got = WebViewStreamService.pickWebAudio({
        'status': 'OK',
        'adaptiveFormats': [
          {'itag': 140, 'mime': 'audio/mp4', 'bitrate': 128000},
          fmt(itag: 139, mime: 'audio/mp4', br: 48000, url: uAacLo),
        ],
      });
      expect(got, isNotNull);
      expect(got!['url'], uAacLo);
    });

    test('status OK degilse null doner', () {
      for (final s in ['LOGIN_REQUIRED', 'NO_RESPONSE', 'JS_ERROR', '?']) {
        expect(
          WebViewStreamService.pickWebAudio({
            'status': s,
            'adaptiveFormats': [
              fmt(itag: 140, mime: 'audio/mp4', br: 128000, url: uAacHi),
            ],
          }),
          isNull,
          reason: 'status=$s',
        );
      }
    });

    test('bos/bozuk veride null doner', () {
      expect(WebViewStreamService.pickWebAudio(const {}), isNull);
      expect(
          WebViewStreamService.pickWebAudio(
              {'status': 'OK', 'adaptiveFormats': []}),
          isNull);
      expect(
          WebViewStreamService.pickWebAudio({'status': 'OK'}), isNull);
    });
  });
}
