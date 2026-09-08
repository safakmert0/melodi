import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// YouTube sağlayıcı: uygulamaya gömülü SpotiFLAC paketi (assets içinde
/// pinli `ytmusic-spotiflac.sflx`), quickjs'de çalışır.
///
/// Ne sunucu ister ne hesap: arama `customSearch`, indirme
/// `checkAvailability` + `download` (InnerTube → Cobalt → yt1d) hattıyla
/// yapılır. Ağ izinleri paketin kendi manifestindeki listedir.
class YtMusicBundle {
  YtMusicBundle._();
  static final YtMusicBundle _instance = YtMusicBundle._();
  factory YtMusicBundle() => _instance;
  static YtMusicBundle get instance => _instance;

  static const String assetPath = 'assets/extensions/ytmusic-spotiflac.sflx';
  static const String bundleVersion = '2.4.1';

  static const List<String> _networkPermissions = [
    'music.youtube.com',
    '*.youtube.com',
    'www.youtube.com',
    'i.ytimg.com',
    '*.googlevideo.com',
    '*.pictube.app',
    'api.zarz.moe',
    'api.deezer.com',
    'yt1d.io',
  ];

  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  JavascriptRuntime? _runtime;
  bool _loadFailed = false;

  bool _isAllowed(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return _networkPermissions.any((raw) {
      final allowed = raw
          .replaceFirst(RegExp(r'^https?://'), '')
          .split('/')
          .first
          .toLowerCase();
      if (allowed.startsWith('*.')) {
        return host.endsWith(allowed.substring(1));
      }
      return host == allowed || host.endsWith('.$allowed');
    });
  }

  Future<JavascriptRuntime> _getRuntime() async {
    final existing = _runtime;
    if (existing != null) return existing;
    if (_loadFailed) throw StateError('YouTube paketi yüklenemedi');

    try {
      final bytes = await rootBundle.load(assetPath);
      final raw = bytes.buffer.asUint8List();
      final archive = ZipDecoder().decodeBytes(raw);
      String? jsCode;
      for (final file in archive) {
        if (file.isFile &&
            (file.name == 'index.js' || file.name.endsWith('.js'))) {
          jsCode = utf8.decode(file.content as List<int>);
          if (file.name == 'index.js') break;
        }
      }
      if (jsCode == null || jsCode.isEmpty) {
        throw StateError('Pakette index.js yok');
      }

      final runtime = getJavascriptRuntime();
      runtime.evaluate(_polyfill);
      runtime.evaluate(jsCode);
      runtime.evaluate(
          'try { if (typeof __registeredExtension !== \'undefined\' && __registeredExtension) { globalThis.extension = __registeredExtension; } } catch (e) {}');
      _runtime = runtime;
      return runtime;
    } catch (e) {
      _loadFailed = true;
      throw StateError('YouTube paketi yüklenemedi: $e');
    }
  }

  static const String _polyfill = '''
      var module = { exports: {} };
      var exports = module.exports;
      var global = globalThis;
      var __registeredExtension = null;
      function registerExtension(obj) {
        __registeredExtension = obj || {};
        try { globalThis.extension = __registeredExtension; } catch (e) {}
        try { if (__registeredExtension.initialize) __registeredExtension.initialize({}); } catch (e) {}
        return true;
      }
      var __extensionStorage = {};
      var __nativeHttpCache = {};
      var __settingDefaults = {};
      var storage = {
        get: function(k) { return __extensionStorage[k] === undefined ? null : __extensionStorage[k]; },
        set: function(k,v) { __extensionStorage[k] = v; return true; },
        remove: function(k) { delete __extensionStorage[k]; return true; }
      };
      var settings = {
        get: function(k, fallback) {
          if (__extensionStorage['setting:' + k] !== undefined) return __extensionStorage['setting:' + k];
          if (__settingDefaults[k] !== undefined) return __settingDefaults[k];
          return fallback === undefined ? null : fallback;
        },
        set: function(k, v) { __extensionStorage['setting:' + k] = v; return true; }
      };
      var __b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
      function btoa(input) {
        var out='', i=0, c1, c2, c3;
        input = unescape(encodeURIComponent(input));
        while (i < input.length) {
          c1=input.charCodeAt(i++); c2=input.charCodeAt(i++); c3=input.charCodeAt(i++);
          out += __b64.charAt(c1>>2) + __b64.charAt(((c1&3)<<4)|(c2>>4)) +
            __b64.charAt(isNaN(c2)?64:(((c2&15)<<2)|(c3>>6))) +
            __b64.charAt(isNaN(c3)?64:(c3&63));
        }
        return out;
      }
      function atob(input) {
        var out='', i=0, e1,e2,e3,e4,c1,c2,c3;
        input=input.replace(/[^A-Za-z0-9+\\/=]/g,'');
        while(i<input.length){e1=__b64.indexOf(input.charAt(i++));e2=__b64.indexOf(input.charAt(i++));e3=__b64.indexOf(input.charAt(i++));e4=__b64.indexOf(input.charAt(i++));c1=(e1<<2)|(e2>>4);c2=((e2&15)<<4)|(e3>>2);c3=((e3&3)<<6)|e4;out+=String.fromCharCode(c1);if(e3!=64)out+=String.fromCharCode(c2);if(e4!=64)out+=String.fromCharCode(c3);}
        return decodeURIComponent(escape(out));
      }
      function __syncHttp(method, url, body, headers) {
        var request = {method:String(method || 'GET').toUpperCase(), url:String(url), body:body == null ? null : (typeof body === 'string' ? body : JSON.stringify(body)), headers:headers || {}};
        var key = JSON.stringify(request);
        if (__nativeHttpCache[key] !== undefined) return __nativeHttpCache[key];
        throw new Error('__MELODI_HTTP__' + btoa(unescape(encodeURIComponent(key))));
      }
      var http = {
        get:function(url, headers){ return __syncHttp('GET', url, null, headers); },
        post:function(url, body, headers){ return __syncHttp('POST', url, body, headers); },
        put:function(url, body, headers){ return __syncHttp('PUT', url, body, headers); },
        patch:function(url, body, headers){ return __syncHttp('PATCH', url, body, headers); },
        delete:function(url, headers){ return __syncHttp('DELETE', url, null, headers); },
        request:function(url, options){ options=options || {}; return __syncHttp(options.method || 'GET', url, options.body, options.headers); },
        clearCookies:function(){ return true; }
      };
      function __syncFile(op, a, b, c) {
        var request = {op:op, a:(a===undefined?null:a), b:(b===undefined?null:b), c:(c===undefined?null:c)};
        var key = 'file:' + JSON.stringify(request);
        if (__nativeHttpCache[key] !== undefined) return __nativeHttpCache[key];
        throw new Error('__MELODI_FILE__' + btoa(unescape(encodeURIComponent(JSON.stringify(request)))));
      }
      var file = {
        exists:function(p){ return __syncFile('exists', String(p)); },
        delete:function(p){ return __syncFile('delete', String(p)); },
        download:function(url, outputPath, options){ return __syncFile('download', String(url), String(outputPath||''), options||{}); },
        downloadChunked:function(url, outputPath, options){ return __syncFile('download', String(url), String(outputPath||''), options||{}); },
        downloadSegments:function(segments){
          var first = Array.isArray(segments) && segments.length ? (segments[0].url || segments[0]) : null;
          return first ? {success:true, path:String(first), url:String(first)} : {success:false, error:'no segments'};
        }
      };
      function __syncCrypto(op, value, key) {
        var request = {op:op, value:value, key:key == null ? null : key};
        var cacheKey = 'crypto:' + JSON.stringify(request);
        if (__nativeHttpCache[cacheKey] !== undefined) return __nativeHttpCache[cacheKey];
        throw new Error('__MELODI_CRYPTO__' + btoa(unescape(encodeURIComponent(JSON.stringify(request)))));
      }
      var utils = {
        appUserAgent:function(){ return '$_userAgent'; },
        randomUserAgent:function(){ return '$_userAgent'; },
        appVersion:function(){ return '5.2.0'; },
        sleep:function(){ return true; },
        isDownloadCancelled:function(){ return false; },
        isRequestCancelled:function(){ return false; },
        sha256:function(value){ return __syncCrypto('sha256', value); },
        md5:function(value){ return __syncCrypto('md5', value); },
        hmacSHA1:function(value, key){ return __syncCrypto('hmacSHA1', value, key); },
        base64Decode:function(value){
          var raw=atob(String(value)); var out=[];
          for(var i=0;i<raw.length;i++) out.push(raw.charCodeAt(i)&255);
          return out;
        }
      };
      var log = {
        debug:function(){},
        info:function(){},
        warn:function(){},
        error:function(){}
      };
      var console = log;
      function __fetchResponse(cached) {
        return {
          ok: !!cached.ok,
          status: cached.status,
          headers: cached.headers || {},
          url: cached.url,
          text: function() { return cached.body; },
          json: function() { return JSON.parse(cached.body); },
          arrayBuffer: function() { return cached.bodyBase64; }
        };
      }
      function fetch(url, options) {
        options = options || {};
        var req = {
          method: String(options.method || 'GET').toUpperCase(),
          url: String(url),
          body: (options.body == null ? null : (typeof options.body === 'string' ? options.body : JSON.stringify(options.body))),
          headers: options.headers || {}
        };
        var key = JSON.stringify(req);
        if (__nativeHttpCache[key] !== undefined) return __fetchResponse(__nativeHttpCache[key]);
        throw new Error('__MELODI_HTTP__' + btoa(unescape(encodeURIComponent(key))));
      }
    ''';

  Future<dynamic> _evaluateWithReplay(
    JavascriptRuntime runtime,
    String script,
  ) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      final result = await runtime.evaluateAsync(script);
      final raw = result.stringResult;
      final httpMarker =
          RegExp(r'__MELODI_HTTP__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final cryptoMarker =
          RegExp(r'__MELODI_CRYPTO__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final fileMarker =
          RegExp(r'__MELODI_FILE__([A-Za-z0-9+/=]+)').firstMatch(raw);
      if (httpMarker == null && cryptoMarker == null && fileMarker == null) {
        return result;
      }
      if (cryptoMarker != null) {
        final requestJson = utf8.decode(base64Decode(cryptoMarker.group(1)!));
        final request = jsonDecode(requestJson) as Map<String, dynamic>;
        List<int> bytesOf(Object? value) => value is List
            ? value.map((item) => (item as num).toInt() & 0xff).toList()
            : utf8.encode(value?.toString() ?? '');
        final value = bytesOf(request['value']);
        final key = bytesOf(request['key']);
        final op = request['op']?.toString();
        final Object response = switch (op) {
          'md5' => md5.convert(value).toString(),
          'hmacSHA1' => Hmac(sha1, key).convert(value).bytes,
          _ => sha256.convert(value).toString(),
        };
        runtime.evaluate(
          '__nativeHttpCache[${jsonEncode('crypto:$requestJson')}] = '
          '${jsonEncode(response)};',
        );
        continue;
      }
      if (fileMarker != null) {
        final fileRequestJson =
            utf8.decode(base64Decode(fileMarker.group(1)!));
        final fileRequest = jsonDecode(fileRequestJson) as Map<String, dynamic>;
        final fileResponse = await _nativeFileOp(fileRequest);
        runtime.evaluate(
          '__nativeHttpCache[${jsonEncode('file:$fileRequestJson')}] = '
          '${jsonEncode(fileResponse)};',
        );
        continue;
      }
      final requestJson = utf8.decode(base64Decode(httpMarker!.group(1)!));
      final request = jsonDecode(requestJson) as Map<String, dynamic>;
      final uri = Uri.parse(request['url'].toString());
      if (!_isAllowed(uri)) {
        throw StateError('İzin verilmeyen alan adı: ${uri.host}');
      }
      final method = (request['method']?.toString() ?? 'GET').toUpperCase();
      final headers = (request['headers'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          <String, String>{};
      final body = request['body']?.toString();
      late final int statusCode;
      late final List<int> bytes;
      late final Map<String, String> responseHeaders;
      final response = method == 'GET'
          ? await http
              .get(uri, headers: headers.cast<String, String>())
              .timeout(const Duration(seconds: 25))
          : await http
              .post(uri,
                  headers: headers.cast<String, String>(), body: body)
              .timeout(const Duration(seconds: 25));
      statusCode = response.statusCode;
      bytes = response.bodyBytes;
      responseHeaders = response.headers;
      runtime.evaluate(
        '__nativeHttpCache[${jsonEncode(requestJson)}] = '
        '${jsonEncode({
          'statusCode': statusCode,
          'status': statusCode,
          'ok': statusCode >= 200 && statusCode < 300,
          'url': uri.toString(),
          'body': utf8.decode(bytes, allowMalformed: true),
          'bodyBase64': base64Encode(bytes),
          'headers': responseHeaders,
        })};',
      );
    }
    throw StateError('Eklenti çok fazla ardışık ağ isteği oluşturdu');
  }

  Future<Object?> _nativeFileOp(Map<String, dynamic> req) async {
    final op = req['op']?.toString();
    try {
      if (op == 'exists') {
        return File(req['a']?.toString() ?? '').existsSync();
      }
      if (op == 'delete') {
        try {
          await File(req['a']?.toString() ?? '').delete();
        } catch (_) {}
        return true;
      }
      if (op == 'download') {
        final options = req['c'];
        return await _nativeFileDownload(
          req['a']?.toString() ?? '',
          req['b']?.toString() ?? '',
          options is Map ? Map<String, dynamic>.from(options) : const {},
        );
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'unknown file op: $op'};
  }

  Future<Map<String, dynamic>> _nativeFileDownload(
    String url,
    String outputPath,
    Map<String, dynamic> options,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return {'success': false, 'error': 'bad url'};
    }
    if (!_isAllowed(uri)) {
      return {'success': false, 'error': 'domain not allowed: ${uri.host}'};
    }
    var path = outputPath.trim();
    if (path.isEmpty) {
      final tmp = await getTemporaryDirectory();
      path =
          '${tmp.path}/melodi_yt_${DateTime.now().millisecondsSinceEpoch}.bin';
    }
    final headers = <String, String>{};
    final optionHeaders = options['headers'];
    if (optionHeaders is Map) {
      optionHeaders.forEach((key, value) {
        if (value != null) headers[key.toString()] = value.toString();
      });
    }
    headers.putIfAbsent('User-Agent', () => _userAgent);
    final referer = options['referer']?.toString();
    if (referer != null && referer.isNotEmpty) headers['Referer'] = referer;
    final origin = options['origin']?.toString();
    if (origin != null && origin.isNotEmpty) headers['Origin'] = origin;

    final file = File(path);
    try {
      await file.parent.create(recursive: true);
    } catch (e) {
      return {'success': false, 'error': 'cannot create dir: $e'};
    }
    var offset = 0;
    try {
      if (await file.exists()) offset = await file.length();
    } catch (_) {
      offset = 0;
    }
    final chunkSize = (options['chunkSize'] as num?)?.toInt() ?? 0;
    const maxChunks = 600;
    const maxTotalBytes = 1024 * 1024 * 1024;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      while (true) {
        if (offset >= maxTotalBytes) {
          return {'success': false, 'error': 'download too large'};
        }
        final request =
            await client.getUrl(uri).timeout(const Duration(seconds: 25));
        request.headers.set('User-Agent', headers['User-Agent']!);
        headers.forEach((key, value) {
          if (key.toLowerCase() == 'user-agent') return;
          try {
            request.headers.set(key, value);
          } catch (_) {}
        });
        final end = chunkSize > 0 ? offset + chunkSize - 1 : null;
        if (offset > 0 || end != null) {
          request.headers.set(HttpHeaders.rangeHeader,
              end != null ? 'bytes=$offset-$end' : 'bytes=$offset-');
        }
        final response =
            await request.close().timeout(const Duration(seconds: 25));
        if (response.statusCode != 200 && response.statusCode != 206) {
          return {'success': false, 'error': 'HTTP ${response.statusCode}'};
        }
        final sink = file.openWrite(
            mode: offset > 0 && response.statusCode == 206
                ? FileMode.append
                : FileMode.write);
        if (offset > 0 && response.statusCode == 200) offset = 0;
        var chunks = 0;
        try {
          await for (final data
              in response.timeout(const Duration(seconds: 60))) {
            sink.add(data);
            offset += data.length;
            if (++chunks > maxChunks || offset >= maxTotalBytes) break;
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        final contentLength = response.contentLength;
        if (end == null) break;
        if (contentLength >= 0 && contentLength < chunkSize) break;
        if (contentLength < 0) break;
      }
      final length = await file.length();
      if (length < 1000) {
        try {
          await file.delete();
        } catch (_) {}
        return {'success': false, 'error': 'empty file'};
      }
      return {'success': true, 'path': path};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    } finally {
      client.close(force: true);
    }
  }

  /// Eşzamanlı köprü çağrılarını native tarafta koşturup betiği baştan
  /// oynatır; işaretçi kalmayınca son sonucu döner.
  Future<dynamic> _evaluateWithHttpReplay(
    JavascriptRuntime runtime,
    String script,
  ) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      final result = await runtime.evaluateAsync(script);
      final raw = result.stringResult;
      final httpMarker =
          RegExp(r'__MELODI_HTTP__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final cryptoMarker =
          RegExp(r'__MELODI_CRYPTO__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final fileMarker =
          RegExp(r'__MELODI_FILE__([A-Za-z0-9+/=]+)').firstMatch(raw);
      if (httpMarker == null && cryptoMarker == null && fileMarker == null) {
        return result;
      }
      if (cryptoMarker != null) {
        final requestJson = utf8.decode(base64Decode(cryptoMarker.group(1)!));
        final request = jsonDecode(requestJson) as Map<String, dynamic>;
        List<int> bytesOf(Object? value) => value is List
            ? value.map((item) => (item as num).toInt() & 0xff).toList()
            : utf8.encode(value?.toString() ?? '');
        final value = bytesOf(request['value']);
        final key = bytesOf(request['key']);
        final op = request['op']?.toString();
        final Object response = switch (op) {
          'md5' => md5.convert(value).toString(),
          'hmacSHA1' => Hmac(sha1, key).convert(value).bytes,
          _ => sha256.convert(value).toString(),
        };
        runtime.evaluate(
          '__nativeHttpCache[${jsonEncode('crypto:$requestJson')}] = '
          '${jsonEncode(response)};',
        );
        continue;
      }
      if (fileMarker != null) {
        final fileRequestJson =
            utf8.decode(base64Decode(fileMarker.group(1)!));
        final fileRequest = jsonDecode(fileRequestJson) as Map<String, dynamic>;
        final fileResponse = await _nativeFileOp(fileRequest);
        runtime.evaluate(
          '__nativeHttpCache[${jsonEncode('file:$fileRequestJson')}] = '
          '${jsonEncode(fileResponse)};',
        );
        continue;
      }
      final requestJson = utf8.decode(base64Decode(httpMarker!.group(1)!));
      final request = jsonDecode(requestJson) as Map<String, dynamic>;
      final uri = Uri.parse(request['url'].toString());
      if (!_isAllowed(uri)) {
        throw StateError('İzin verilmeyen alan adı: ${uri.host}');
      }
      final method = (request['method']?.toString() ?? 'GET').toUpperCase();
      final headers = (request['headers'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          <String, String>{};
      final body = request['body']?.toString();
      final response = method == 'GET'
          ? await http
              .get(uri, headers: headers.cast<String, String>())
              .timeout(const Duration(seconds: 25))
          : await http
              .post(uri,
                  headers: headers.cast<String, String>(), body: body)
              .timeout(const Duration(seconds: 25));
      runtime.evaluate(
        '__nativeHttpCache[${jsonEncode(requestJson)}] = '
        '${jsonEncode({
          'statusCode': response.statusCode,
          'status': response.statusCode,
          'ok': response.statusCode >= 200 && response.statusCode < 300,
          'url': uri.toString(),
          'body': utf8.decode(response.bodyBytes, allowMalformed: true),
          'bodyBase64': base64Encode(response.bodyBytes),
          'headers': response.headers,
        })};',
      );
    }
    throw StateError('Paket çok fazla ardışık ağ isteği oluşturdu');
  }

  /// Pakette arama: `customSearch` aynı sözleşmeyle çağrılır.
  Future<List<Map<String, dynamic>>> search(String query,
      {int limit = 20}) async {
    final runtime = await _getRuntime();
    final encodedQuery = jsonEncode(query);
    const js = '''
      (function() {
        try {
          var e = (typeof globalThis !== 'undefined' && globalThis.__registeredExtension) ||
            (typeof extension !== 'undefined' ? extension : null);
          if (!e || typeof e.customSearch !== 'function') return JSON.stringify({error:'search not found'});
          var res = e.customSearch(QUERY, {limit:LIMIT, filter:'tracks', type:'tracks'});
          if (res && typeof res === 'object' && !Array.isArray(res)) res = res.results || res.tracks || res.items || [];
          return JSON.stringify({results: res});
        } catch (e) { return JSON.stringify({error:String(e)}); }
      })()
    ''';
    // customSearch eşzamanlıdır; yine de replay döngüsünden geçir.
    final result = await _evaluateWithReplay(
      runtime,
      js
          .replaceAll('QUERY', encodedQuery)
          .replaceAll('LIMIT', limit.toString()),
    );
    final str = result.stringResult;
    try {
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      if (decoded.containsKey('error')) throw Exception(decoded['error']);
      final results = decoded['results'] as List? ?? [];
      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('YouTube araması başarısız: $e');
    }
  }

  /// Paketin kendi indirme hattı: önce eşleşme, sonra gerçek dosya.
  /// Dönüş: {success, file_path, actual_extension, cover_url, error}
  Future<Map<String, dynamic>?> downloadToFile({
    required String trackId,
    String title = '',
    String artist = '',
    String quality = 'best',
    required String outputPath,
  }) async {
    final runtime = await _getRuntime();
    final js = '''
      (async function() {
        try {
          var e = (typeof globalThis !== 'undefined' && globalThis.__registeredExtension) ||
            (typeof extension !== 'undefined' ? extension : null);
          if (!e || typeof e.download !== 'function') return JSON.stringify({error:'download not found'});
          var id = ${jsonEncode(trackId)};
          if (typeof e.checkAvailability === 'function') {
            try {
              var availability = await e.checkAvailability('', ${jsonEncode(title)}, ${jsonEncode(artist)}, {});
              if (availability === false || (availability && availability.available === false)) {
                return JSON.stringify({error:'unavailable'});
              }
              if (availability && typeof availability === 'object' && availability.track_id) id = availability.track_id;
            } catch (_) {}
          }
          var result = await e.download(id, ${jsonEncode(quality)}, ${jsonEncode(outputPath)}, function(){});
          result = result || {};
          return JSON.stringify({
            success: !!result.success,
            file_path: result.file_path || result.path || '',
            actual_extension: result.actual_extension || result.output_extension || '',
            cover_url: result.cover_url || '',
            error: result.error_message || result.error || ''
          });
        } catch (e) { return JSON.stringify({error:String(e)}); }
      })()
    ''';
    final result = await _evaluateWithHttpReplay(runtime, js);
    try {
      final decoded = jsonDecode(result.stringResult);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['error'] != null &&
          map['error'].toString().isNotEmpty &&
          map['success'] != true) {
        return {'success': false, 'error': map['error'].toString()};
      }
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Oynatma için akış yolu: dosyayı geçici dizine indirir, gerçek yolu döner.
  /// Uzantı `actual_extension` ile düzeltilir.
  Future<String?> getPlayablePath({
    required String trackId,
    String title = '',
    String artist = '',
  }) async {
    final tmp = await getTemporaryDirectory();
    final out =
        '${tmp.path}/melodi_play_${DateTime.now().millisecondsSinceEpoch}.bin';
    final result = await downloadToFile(
      trackId: trackId,
      title: title,
      artist: artist,
      outputPath: out,
    );
    if (result == null || result['success'] != true) return null;
    var path = (result['file_path'] ?? '').toString();
    if (path.isEmpty) return null;
    final actualExt = (result['actual_extension'] ?? '').toString();
    if (actualExt.isNotEmpty &&
        !path.toLowerCase().endsWith(actualExt.toLowerCase())) {
      try {
        final normalizedExt =
            actualExt.startsWith('.') ? actualExt : '.$actualExt';
        final renamed = path.replaceFirst(
            RegExp(r'\.[A-Za-z0-9]{1,5}$'), normalizedExt);
        if (renamed != path) {
          await File(path).rename(renamed);
          path = renamed;
        }
      } catch (_) {}
    }
    try {
      if (!await File(path).exists()) return null;
    } catch (_) {
      return null;
    }
    return path;
  }
}
