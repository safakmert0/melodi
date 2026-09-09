import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/player_provider.dart';
import '../services/embed_playback_service.dart';
import '../services/music_source.dart';

/// JollyTone tarzi gomulu oynatici: direkt stream blokluysa embed ile dinle.
/// Controller serviste yasar; geri donunce muzik durmaz, mini player'da surer.
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
    final svc = EmbedPlaybackService.instance;
    _controller = svc.controller();
    _controller.setNavigationDelegate(
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
    );
    // Iki ses ust uste binmesin: yerel calis varsa durdur.
    try {
      final player = context.read<PlayerProvider>();
      if (player.isPlaying) unawaited(player.pause());
    } catch (_) {}
    if (svc.activeTrack.value?.id != widget.track.id) {
      unawaited(svc.play(widget.track));
    } else {
      _loading = false;
    }
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
                'Oynatici hatasi: $_error\nBazi kliplerde embed kapali olabilir (Hata 150/153); asagidan YouTube uygulamasinda acmayi dene.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dogrudan akis aginda engelli (YouTube giris korumasi). Gomulu oynatici ile dinliyorsun; geri donsen de muzik surer.',
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
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    unawaited(EmbedPlaybackService.instance
                        .play(widget.track));
                  },
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
