import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Runs Cloudflare's normal, user-visible verification flow and then reuses
/// the WebKit/Android WebView cookies for API requests.
class CloudflareSessionService {
  CloudflareSessionService._();

  static final CloudflareSessionService instance = CloudflareSessionService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  final Map<String, String> _cookieHeaders = <String, String>{};
  final Map<String, Future<bool>> _activeVerifications =
      <String, Future<bool>>{};

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) {
    return _request('GET', uri, headers: headers);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _request('POST', uri, headers: headers, body: body);
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    Future<http.Response> send() {
      final merged = <String, String>{
        'User-Agent': userAgent,
        ...?headers,
      };
      final cookies = _cookieHeaders[uri.host];
      if (cookies != null && cookies.isNotEmpty) merged['Cookie'] = cookies;
      return method == 'POST'
          ? http.post(uri, headers: merged, body: body)
          : http.get(uri, headers: merged);
    }

    var response = await send();
    if (!_isChallenge(response)) return response;

    final verified = await verify(uri);
    if (!verified) return response;
    response = await send();
    return response;
  }

  bool _isChallenge(http.Response response) {
    final body = response.body.toLowerCase();
    final cloudflarePage = body.contains('cf-chl-') ||
        body.contains('challenge-platform') ||
        body.contains('just a moment') ||
        body.contains('turnstile');
    return cloudflarePage &&
        (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 503);
  }

  Future<bool> verify(Uri target) {
    final origin = target.replace(path: '/', query: '', fragment: '');
    return _activeVerifications.putIfAbsent(origin.host, () async {
      try {
        final navigator = await _waitForNavigator();
        if (navigator == null) return false;
        final result = await navigator.push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => _CloudflareVerificationScreen(origin: origin),
          ),
        );
        if (result != true) return false;
        await _captureCookies(origin);
        return (_cookieHeaders[origin.host] ?? '').isNotEmpty;
      } finally {
        _activeVerifications.remove(origin.host);
      }
    });
  }

  Future<NavigatorState?> _waitForNavigator() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final navigator = navigatorKey.currentState;
      if (navigator != null) return navigator;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _captureCookies(Uri uri) async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(uri.toString()),
    );
    if (cookies.isEmpty) return;
    _cookieHeaders[uri.host] = cookies
        .where((cookie) => cookie.name.isNotEmpty)
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }
}

class _CloudflareVerificationScreen extends StatefulWidget {
  const _CloudflareVerificationScreen({required this.origin});

  final Uri origin;

  @override
  State<_CloudflareVerificationScreen> createState() =>
      _CloudflareVerificationScreenState();
}

class _CloudflareVerificationScreenState
    extends State<_CloudflareVerificationScreen> {
  bool _checking = false;
  int _progress = 0;

  Future<void> _checkCompleted() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final clearance = await CookieManager.instance().getCookie(
        url: WebUri(widget.origin.toString()),
        name: 'cf_clearance',
      );
      if (clearance != null && clearance.value.isNotEmpty && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik doğrulaması'),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.origin.toString())),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            thirdPartyCookiesEnabled: true,
            userAgent: CloudflareSessionService.userAgent,
            transparentBackground: false,
          ),
          onProgressChanged: (_, progress) {
            if (mounted) setState(() => _progress = progress);
            if (progress == 100) unawaited(_checkCompleted());
          },
          onLoadStop: (_, __) => _checkCompleted(),
        ),
      ),
    );
  }
}
