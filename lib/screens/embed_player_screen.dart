import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../services/embed_playback_service.dart';
import '../services/music_source.dart';

/// JollyTone tarzi gomulu oynatici: direkt stream blokluysa embed ile dinle.
class EmbedPlayerScreen extends StatefulWidget {
  const EmbedPlayerScreen({super.key, required this.track});
  final OnlineTrack track;

  @override
  State<EmbedPlayerScreen> createState() => _EmbedPlayerScreenState();
}

class _EmbedPlayerScreenState extends State<EmbedPlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // iOS: satir ici medya + otomatik oynatmaya izin ver, yoksa
    // YouTube embed "yapilandirma hatasi" gosteriyor.
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {},
      );
    }
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(EmbedPlaybackService.embedUrl(widget.track.id)),
      );
  }

  Future<void> _openInYouTube() async {
    final uri = Uri.parse(EmbedPlaybackService.watchUrl(widget.track.id));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
            Text(t.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Oynatici hatasi: $_error\nBazi kliplerde embed kapali olabilir; asagidan YouTube uygulamasinda acmayi dene.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dogrudan akis aginda engelli (YouTube giris korumasi). Gomulu oynatici ile dinliyorsun; indirme bu parcada kapali olabilir.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _controller.reload(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tekrar dene'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openInYouTube,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text("YouTube'da aç"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
