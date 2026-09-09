import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'music_source.dart';

/// JollyTone parity: WebView embed oynatma.
/// Dogrudan InnerTube player LOGIN_REQUIRED dondugunde (2026 bot korumasi),
/// `youtube-nocookie.com/embed/VIDEO_ID` bazi aglarda calisir.
///
/// Sureklilik: controller singleton tutulur; ekrandan geri donunce
/// webview yikilmaz, ses calmaya devam eder ve mini player'da gorunur.
class EmbedPlaybackService {
  EmbedPlaybackService._();
  static final EmbedPlaybackService _instance = EmbedPlaybackService._();
  factory EmbedPlaybackService() => _instance;
  static EmbedPlaybackService get instance => _instance;

  static final RegExp _idExp = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static bool isPlayableId(String id) => _idExp.hasMatch(id.trim());

  static String embedUrl(String videoId, {bool autoplay = true}) {
    final id = videoId.trim();
    final auto = autoplay ? '1' : '0';
    // nocookie embed, kisitli kliplerde daha az "yapilandirma hatasi" veriyor.
    return 'https://www.youtube-nocookie.com/embed/$id?autoplay=$auto&playsinline=1&rel=0&enablejsapi=1&origin=https://www.youtube.com';
  }

  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=${videoId.trim()}';

  WebViewController? _controller;

  /// Su an gomulu calan parca (null ise gomulu calis yok).
  final ValueNotifier<OnlineTrack?> activeTrack =
      ValueNotifier<OnlineTrack?>(null);

  /// Ekrandan bagimsiz yasayan paylasilan controller.
  WebViewController controller() {
    final existing = _controller;
    if (existing != null) return existing;
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {},
      );
    }
    final c = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000));
    _controller = c;
    return c;
  }

  Future<void> play(OnlineTrack track) async {
    final c = controller();
    activeTrack.value = track;
    try {
      await c.loadRequest(Uri.parse(embedUrl(track.id)));
    } catch (e) {
      debugPrint('Embed play error: $e');
    }
  }

  void stop() {
    activeTrack.value = null;
    try {
      final c = _controller;
      if (c != null) unawaited(c.loadRequest(Uri.parse('about:blank')));
    } catch (_) {}
  }

  void logFallback(String videoId, String reason) {
    debugPrint('Embed fallback: $videoId ($reason)');
  }
}
