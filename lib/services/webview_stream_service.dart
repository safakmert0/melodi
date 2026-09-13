import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Gizli tarayiciyla akis cozme (musx tarifi).
///
/// El yapimi InnerTube istekleri IP/istemci surumu yuzunden bot duvarina
/// (LOGIN_REQUIRED) takilabiliyor. Gercek bir WKWebView icinde watch
/// sayfasi acilip `ytInitialPlayerResponse` okununca YouTube'un KENDI
/// oynaticisi cozumu yapar: n/imza gecerli, kisitlamasiz URL gelir.
/// Hizli baslar, AVPlayer uyumludur.
///
/// Kullanim: once backend proxy, sonra bu servis, sonra diger yedekler.
class WebViewStreamService {
  WebViewStreamService._();
  static final WebViewStreamService _instance = WebViewStreamService._();
  factory WebViewStreamService() => _instance;
  static WebViewStreamService get instance => _instance;

  HeadlessInAppWebView? _webview;
  bool _running = false;
  Future<void>? _starting;
  Completer<void>? _pageReady;
  String? _loadingVideoId;

  // Ayni anda tek cozum (tek gizli tarayici).
  Future<Map<String, dynamic>?>? _activeResolve;

  static const Duration _resolveTimeout = Duration(seconds: 35);

  /// Cozumlenmis ses akisi: {url, ext, itag} ya da null.
  Future<Map<String, dynamic>?> resolveAudio(String videoId) {
    final id = videoId.trim();
    if (id.isEmpty) return Future.value();
    // Seri calistir: onceki bitmeden yenisi baslamaz.
    final mine = (_activeResolve ?? Future.value()).then((_) => _doResolve(id));
    _activeResolve = mine.then((v) => v, onError: (_) => null);
    return mine.timeout(_resolveTimeout, onTimeout: () => null);
  }

  Future<Map<String, dynamic>?> _doResolve(String id) async {
    debugPrint('🌐 WebViewStream: _doResolve START for $id');
    try {
      await _ensureRunning();
      final controller = _webview?.webViewController;
      if (controller == null) {
        debugPrint('❌ WebViewStream: controller is null');
        return null;
      }
      _loadingVideoId = id;
      _pageReady = Completer<void>();
      debugPrint('🌐 WebViewStream: loading URL for $id');
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('https://m.youtube.com/watch?v=$id&hl=en'),
        ),
      );
      // Sayfa + oynatici verisi en fazla 20 sn beklenir.
      try {
        await _pageReady!.future.timeout(const Duration(seconds: 20));
        debugPrint('🌐 WebViewStream: pageReady completed for $id');
      } catch (_) {
        debugPrint('🌐 WebViewStream: pageReady timeout, trying anyway for $id');
      }
      final raw = await controller
          .evaluateJavascript(source: _extractJs)
          .timeout(const Duration(seconds: 10));
      debugPrint('🌐 WebViewStream: JS evaluated for $id, raw length: ${raw?.toString().length ?? 0}');
      final result = pickWebAudio(_decodePayload(raw));
      if (result != null) {
        debugPrint('✅ WebViewStream: pickWebAudio SUCCESS for $id');
      } else {
        debugPrint('❌ WebViewStream: pickWebAudio returned null for $id');
      }
      return result;
    } catch (e) {
      debugPrint('❌ WebViewStream resolve error for $id: $e');
      return null;
    } finally {
      _loadingVideoId = null;
    }
  }

  Future<void> _ensureRunning() {
    if (_running) return Future.value();
    _starting ??= _start();
    return _starting!;
  }

  Future<void> _start() async {
    final w = HeadlessInAppWebView(
      initialUrlRequest:
          URLRequest(url: WebUri('https://m.youtube.com/?hl=en')),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: true,
      ),
      onLoadStop: (controller, url) async {
        if (_loadingVideoId == null) return;
        // Oynatici verisi geldi mi diye yokla.
        for (var i = 0; i < 20; i++) {
          try {
            final probe = await controller
                .evaluateJavascript(source: _probeJs)
                .timeout(const Duration(seconds: 3));
            if (probe.toString().contains('READY')) break;
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (!(_pageReady?.isCompleted ?? true)) _pageReady?.complete();
      },
    );
    await w.run();
    _webview = w;
    _running = true;
  }

  /// Kopru ciktisini Map'e cevir (String JSON ya da dogrudan Map).
  static Map<String, dynamic> _decodePayload(dynamic raw) {
    try {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const {};
  }

  /// Oynatici verisinden en iyi dogrudan AAC URL'i sec.
  /// Donus: {url, ext, itag} ya da null (cipher'li/yok).
  static Map<String, dynamic>? pickWebAudio(Map<String, dynamic> data) {
    try {
      debugPrint('🌐 WebViewStream: pickWebAudio called, status=${data['status']}, adaptiveCount=${(data['adaptiveFormats'] as List?)?.length ?? 0}');
      if ((data['status']?.toString() ?? '') != 'OK') {
        debugPrint('❌ pickWebAudio: status not OK');
        return null;
      }
      final adaptive = data['adaptiveFormats'];
      if (adaptive is! List || adaptive.isEmpty) {
        debugPrint('❌ pickWebAudio: adaptiveFormats empty or not a list');
        return null;
      }
      Map<String, dynamic>? bestAac;
      var bestAacBr = -1;
      var aacCount = 0;
      for (final raw in adaptive) {
        if (raw is! Map) continue;
        final f = Map<String, dynamic>.from(raw);
        final url = f['url']?.toString() ?? '';
        if (url.isEmpty || !url.startsWith('http')) continue;
        final mime = f['mime']?.toString().toLowerCase() ?? '';
        final br = (f['bitrate'] as num?)?.toInt() ?? 0;
        final isAac = mime.contains('mp4') || mime.contains('m4a');
        if (isAac) {
          aacCount++;
          debugPrint('🌐 pickWebAudio: AAC candidate itag=${f['itag']} br=$br mime=$mime');
        } else {
          debugPrint('🌐 pickWebAudio: NON-AAC itag=${f['itag']} br=$br mime=$mime');
        }
        if (isAac && br > bestAacBr) {
          bestAacBr = br;
          bestAac = f;
        }
      }
      debugPrint('🌐 pickWebAudio: aacCount=$aacCount bestAac=${bestAac != null} bestBr=$bestAacBr');
      // AVPlayer opus calamaz: sadece AAC, yoksa yedege dus (null).
      final pick = bestAac;
      if (pick == null) {
        debugPrint('❌ pickWebAudio: no AAC format found');
        return null;
      }
      final itag = (pick['itag'] as num?)?.toInt() ?? 140;
      debugPrint('✅ pickWebAudio: SELECTED itag=$itag');
      return {'url': pick['url'].toString(), 'ext': '.m4a', 'itag': itag};
    } catch (e) {
      debugPrint('❌ pickWebAudio exception: $e');
      return null;
    }
  }

  /// Sayfa ici cikarma betigi: yalnizca gerekli alanlar (kopru hizli olsun).
  static const String _extractJs = '''
(function(){
  try {
    var pr = window.ytInitialPlayerResponse || null;
    if (!pr) return JSON.stringify({status:'NO_RESPONSE'});
    var ps = pr.playabilityStatus || {};
    var sd = pr.streamingData || {};
    function slim(list){
      var out = [];
      for (var i=0;i<list.length;i++){
        var f = list[i]||{};
        if (!f.url) continue;
        out.push({itag:f.itag, mime:f.mimeType, bitrate:(f.averageBitrate||f.bitrate||0), url:f.url});
      }
      return out;
    }
    return JSON.stringify({
      status: ps.status||'?',
      adaptiveFormats: slim(sd.adaptiveFormats||[])
    });
  } catch(e){ return JSON.stringify({status:'JS_ERROR'}); }
})()
''';

  /// Hizli yoklama: veri hazirsa READY icerir.
  static const String _probeJs = '''
(function(){
  try {
    var pr = window.ytInitialPlayerResponse;
    if (pr && pr.streamingData) return 'READY';
  } catch(e){}
  return 'WAIT';
})()
''';

  Future<void> dispose() async {
    try {
      await _webview?.dispose();
    } catch (_) {}
    _webview = null;
    _running = false;
    _starting = null;
  }
}
