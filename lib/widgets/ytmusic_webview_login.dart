import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YTMusicWebViewLogin extends StatefulWidget {
  final void Function(String cookieString) onCookieObtained;

  const YTMusicWebViewLogin({super.key, required this.onCookieObtained});

  @override
  State<YTMusicWebViewLogin> createState() => _YTMusicWebViewLoginState();
}

class _YTMusicWebViewLoginState extends State<YTMusicWebViewLogin> {
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
      ..loadRequest(Uri.parse('https://music.youtube.com'));
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
      final cookieString = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      if (cookieString is String && cookieString.contains('SAPISID')) {
        _found = true;
        _pollTimer?.cancel();
        widget.onCookieObtained(cookieString);
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
        title: const Text('YouTube Music'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
