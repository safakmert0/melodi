import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/extension.dart';
import 'cloudflare_session_service.dart';
import 'secure_storage_service.dart';

/// Implements the documented SpotiFLAC signedSession/sessionGrant contract.
/// Verification is always completed by the user in the provider's own page.
class SignedSessionService {
  SignedSessionService._();

  static final SignedSessionService instance = SignedSessionService._();

  final _storage = SecureStorageService.instance;
  final Map<String, Future<_SessionRecord>> _authInFlight = {};
  final Random _random = Random.secure();

  Future<Map<String, dynamic>> signedFetch(
    ExtensionManifest manifest,
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    final config = _SignedSessionConfig.fromManifest(manifest);
    if (config == null) {
      return {'ok': false, 'error': 'signedSession is not configured'};
    }
    try {
      var record = await _ensureSession(manifest.id, config);
      var response = await _send(config, record, method, path, body, headers);
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clear(manifest.id);
        record = await _ensureSession(manifest.id, config);
        response = await _send(config, record, method, path, body, headers);
      }
      return {
        'ok': response.statusCode >= 200 && response.statusCode < 300,
        'status': response.statusCode,
        'statusCode': response.statusCode,
        'body': response.body,
        'headers': response.headers,
        if (response.statusCode < 200 || response.statusCode >= 300)
          'error': 'HTTP ${response.statusCode}',
      };
    } catch (error) {
      return {'ok': false, 'error': error.toString()};
    }
  }

  Future<Map<String, dynamic>> status(ExtensionManifest manifest) async {
    final record = await _load(manifest.id);
    return {
      'authenticated': record?.isUsable ?? false,
      'verification_required': record == null || !record.isUsable,
      'expires_at': record?.expiresAt.toIso8601String(),
      'install_id': record?.installId,
      'session_id': record?.sessionId,
    };
  }

  Future<void> clear(String extensionId) async {
    await _storage.delete(_recordKey(extensionId));
  }

  Future<_SessionRecord> _ensureSession(
    String extensionId,
    _SignedSessionConfig config,
  ) async {
    final existing = await _load(extensionId);
    if (existing?.isUsable == true) return existing!;
    return _authInFlight.putIfAbsent(extensionId, () async {
      try {
        return await _bootstrap(extensionId, config, existing);
      } finally {
        _authInFlight.remove(extensionId);
      }
    });
  }

  Future<_SessionRecord> _bootstrap(
    String extensionId,
    _SignedSessionConfig config,
    _SessionRecord? previous,
  ) async {
    final installId = previous?.installId ?? _randomHex(16);
    final bootstrapUri = config.url(config.bootstrap).replace(queryParameters: {
      ...config.url(config.bootstrap).queryParameters,
      'app_version': config.appVersion,
      'install_id': installId,
    });
    final response = await CloudflareSessionService.instance.get(
      bootstrapUri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'SpotiFLAC-Mobile/${config.appVersion}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Oturum başlatılamadı: HTTP ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final direct = _recordFromPayload(installId, payload);
    if (direct != null) {
      await _save(extensionId, direct);
      return direct;
    }

    var state = _randomHex(16);
    var authUrl = payload['auth_url']?.toString() ??
        payload['challenge_url']?.toString() ??
        '';
    if (authUrl.isEmpty && payload['challenge_id'] != null) {
      final callback = _withQuery(
        Uri.parse(config.callbackUrl),
        {'cb_version': 'v2grant', 'state': state},
      );
      authUrl = _withQuery(config.url(config.challenge), {
        'id': payload['challenge_id'].toString(),
        'cb': callback.toString(),
      }).toString();
    } else if (authUrl.isNotEmpty) {
      final parsedAuth = Uri.parse(authUrl);
      final serverState = parsedAuth.queryParameters['state'];
      if (serverState != null && serverState.isNotEmpty) state = serverState;
      authUrl = _withQuery(parsedAuth, {'state': state}).toString();
    }
    if (authUrl.isEmpty) {
      throw StateError('Sağlayıcı doğrulama adresi döndürmedi');
    }
    final callback = await CloudflareSessionService.instance.authorize(
      Uri.parse(authUrl),
      callbackSchemes: {Uri.parse(config.callbackUrl).scheme},
    );
    if (callback == null) throw StateError('Doğrulama iptal edildi');
    final callbackState = callback.queryParameters['state'];
    if (callbackState != null && callbackState != state) {
      throw StateError('Doğrulama durum kodu eşleşmedi');
    }
    final grant = callback.queryParameters['grant'] ??
        callback.queryParameters['code'] ??
        _fragmentParameters(callback)['grant'];
    if (grant == null || grant.isEmpty) {
      throw StateError('Doğrulama geri dönüşünde grant bulunamadı');
    }
    final exchange = await CloudflareSessionService.instance.post(
      config.url(config.exchange),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'SpotiFLAC-Mobile/${config.appVersion}',
      },
      body: jsonEncode({
        'grant': grant,
        'install_id': installId,
        'app_version': config.appVersion,
        'platform': config.platform,
      }),
    );
    if (exchange.statusCode < 200 || exchange.statusCode >= 300) {
      throw StateError(
          'Oturum değişimi başarısız: HTTP ${exchange.statusCode}');
    }
    final record = _recordFromPayload(
      installId,
      jsonDecode(exchange.body) as Map<String, dynamic>,
    );
    if (record == null) throw StateError('Oturum yanıtı eksik');
    await _save(extensionId, record);
    return record;
  }

  Future<http.Response> _send(
    _SignedSessionConfig config,
    _SessionRecord record,
    String method,
    String path,
    Object? body,
    Map<String, String> extraHeaders,
  ) async {
    final uri = config.url(path);
    final upperMethod = method.toUpperCase();
    final bodyText = body == null
        ? ''
        : body is String
            ? body
            : jsonEncode(body);
    final timestamp = _timestamp();
    final nonce = _randomHex(12);
    final bodyHash = sha256.convert(utf8.encode(bodyText)).toString();
    final window = DateTime.parse(timestamp).millisecondsSinceEpoch ~/
        1000 ~/
        config.timeWindowSeconds;
    final rollingInput = '$window:${record.sessionId}';
    final rollingKey = _base64UrlNoPadding(
      Hmac(sha256, utf8.encode(record.sessionSecret))
          .convert(utf8.encode(rollingInput))
          .bytes,
    );
    final signingInput = [
      config.schemeLabel,
      upperMethod,
      uri.path,
      '',
      bodyHash,
      timestamp,
      nonce,
      record.sessionId,
      config.appVersion,
      config.platform,
    ].join('\n');
    final signature = _base64UrlNoPadding(
      Hmac(sha256, utf8.encode(rollingKey))
          .convert(utf8.encode(signingInput))
          .bytes,
    );
    final prefix = config.headerPrefix;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (bodyText.isNotEmpty) 'Content-Type': 'application/json',
      'User-Agent': 'SpotiFLAC-Mobile/${config.appVersion}',
      '${prefix}Session': record.sessionId,
      '${prefix}Timestamp': timestamp,
      '${prefix}Nonce': nonce,
      '${prefix}Body-SHA256': bodyHash,
      '${prefix}Signature': signature,
      '${prefix}App-Version': config.appVersion,
      '${prefix}Platform': config.platform,
      ...extraHeaders,
    };
    return http.Response.fromStream(await (http.Request(upperMethod, uri)
          ..headers.addAll(headers)
          ..body = bodyText)
        .send()
        .timeout(const Duration(seconds: 30)));
  }

  _SessionRecord? _recordFromPayload(
      String installId, Map<String, dynamic> value) {
    final id = value['session_id']?.toString() ?? '';
    final secret = value['session_secret']?.toString() ?? '';
    final expires = DateTime.tryParse(value['expires_at']?.toString() ?? '');
    if (id.isEmpty || secret.isEmpty || expires == null) return null;
    return _SessionRecord(installId, id, secret, expires.toUtc());
  }

  Future<_SessionRecord?> _load(String extensionId) async {
    final raw = await _storage.read(_recordKey(extensionId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return _SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(String extensionId, _SessionRecord record) =>
      _storage.write(_recordKey(extensionId), jsonEncode(record.toJson()));

  String _recordKey(String id) => 'signed_session_$id';
  String _randomHex(int bytes) => List<int>.generate(
        bytes,
        (_) => _random.nextInt(256),
      ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  String _timestamp() {
    final now = DateTime.now().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${now.year.toString().padLeft(4, '0')}-'
        '${two(now.month)}-${two(now.day)}T${two(now.hour)}:'
        '${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}Z';
  }

  String _base64UrlNoPadding(List<int> value) =>
      base64UrlEncode(value).replaceAll('=', '');

  Uri _withQuery(Uri uri, Map<String, String> additions) =>
      uri.replace(queryParameters: {...uri.queryParameters, ...additions});

  Map<String, String> _fragmentParameters(Uri uri) {
    try {
      return Uri.splitQueryString(uri.fragment);
    } catch (_) {
      return const {};
    }
  }
}

class _SignedSessionConfig {
  const _SignedSessionConfig({
    required this.baseUrl,
    required this.appVersion,
    required this.platform,
    required this.callbackUrl,
    required this.schemeLabel,
    required this.headerPrefix,
    required this.timeWindowSeconds,
    required this.bootstrap,
    required this.challenge,
    required this.exchange,
  });

  final String baseUrl;
  final String appVersion;
  final String platform;
  final String callbackUrl;
  final String schemeLabel;
  final String headerPrefix;
  final int timeWindowSeconds;
  final String bootstrap;
  final String challenge;
  final String exchange;

  static _SignedSessionConfig? fromManifest(ExtensionManifest manifest) {
    final value = manifest.signedSession;
    if (value == null) return null;
    final endpoints = value['endpoints'] is Map
        ? Map<String, dynamic>.from(value['endpoints'] as Map)
        : const <String, dynamic>{};
    final baseUrl = value['baseUrl']?.toString() ?? '';
    if (Uri.tryParse(baseUrl)?.hasScheme != true) return null;
    return _SignedSessionConfig(
      baseUrl: baseUrl,
      appVersion: value['appVersion']?.toString() ?? manifest.version,
      platform: value['platform']?.toString() ?? 'extension',
      callbackUrl:
          value['callbackUrl']?.toString() ?? 'spotiflac://session-grant',
      schemeLabel: value['schemeLabel']?.toString() ?? 'ZARZ-HMAC-V1',
      headerPrefix: value['headerPrefix']?.toString() ?? 'X-Zarz-',
      timeWindowSeconds:
          int.tryParse(value['timeWindowSeconds']?.toString() ?? '') ?? 300,
      bootstrap: endpoints['bootstrap']?.toString() ?? '/bootstrap',
      challenge: endpoints['challenge']?.toString() ?? '/challenge',
      exchange: endpoints['exchange']?.toString() ?? '/session/exchange',
    );
  }

  Uri url(String path) =>
      Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/')
          .resolve(path.replaceFirst(RegExp(r'^/+'), ''));
}

class _SessionRecord {
  const _SessionRecord(
      this.installId, this.sessionId, this.sessionSecret, this.expiresAt);

  final String installId;
  final String sessionId;
  final String sessionSecret;
  final DateTime expiresAt;

  bool get isUsable =>
      sessionId.isNotEmpty &&
      sessionSecret.isNotEmpty &&
      expiresAt.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
        'install_id': installId,
        'session_id': sessionId,
        'session_secret': sessionSecret,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory _SessionRecord.fromJson(Map<String, dynamic> value) => _SessionRecord(
        value['install_id']?.toString() ?? '',
        value['session_id']?.toString() ?? '',
        value['session_secret']?.toString() ?? '',
        DateTime.parse(value['expires_at'].toString()).toUtc(),
      );
}
