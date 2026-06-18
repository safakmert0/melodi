import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SpotifyWebViewLogin extends StatefulWidget {
  final void Function(String spDcCookie) onCookieObtained;

  const SpotifyWebViewLogin({super.key, required this.onCookieObtained});

  @override
  State<SpotifyWebViewLogin> createState() => _SpotifyWebViewLoginState();
}

class _SpotifyWebViewLoginState extends State<SpotifyWebViewLogin> {
  late WebViewController _controller;
  Timer? _pollTimer;
  bool _found = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: _onPageFinished,
      ))
      ..loadRequest(Uri.parse('https://accounts.spotify.com/en/login'));
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkCookies());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _onPageFinished(String url) async {
    await _checkCookies();
  }

  Future<void> _checkCookies() async {
    if (_found) return;
    try {
      final cookies = await WebViewCookieManager().getCookies(domain: Uri.parse('https://open.spotify.com'));
      for (final c in cookies) {
        if (c.name == 'sp_dc' && c.value.isNotEmpty && c.value.length > 10) {
          _found = true;
          _pollTimer?.cancel();
          widget.onCookieObtained(c.value);
          return;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Spotify'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
