import 'package:flutter/foundation.dart';

/// JollyTone parity: WebView embed oynatma.
/// Dogrudan InnerTube player LOGIN_REQUIRED dondugunde (2026 bot korumasi),
/// `youtube.com/embed/VIDEO_ID` her agda calisir. Indirme degil, dinleme hattidir.
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
    return 'https://www.youtube.com/embed/$id?autoplay=$auto&playsinline=1&rel=0';
  }

  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=${videoId.trim()}';

  void logFallback(String videoId, String reason) {
    debugPrint('Embed fallback: $videoId ($reason)');
  }
}
