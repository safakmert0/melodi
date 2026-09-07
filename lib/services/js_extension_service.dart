import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/extension.dart';
import 'cloudflare_session_service.dart';
import 'signed_session_service.dart';
import 'secure_storage_service.dart';

/// SpotiFLAC/8spine için JS sandbox — .sflx/.8spine (zip) içindeki index.js'yi
/// quickjs'de çalıştırır. Paketler `registerExtension({...})` sözleşmesiyle
/// kaydolur; `customSearch`/`checkAvailability`/`download` buradan çağrılır.
/// `file.download` gerçekten dosya indirir, bu yüzden eklenti hattı hem
/// çevrimiçi çalma (dosya oynatma) hem indirme için kalıcı çözümdür.
class JsExtensionService {
  JsExtensionService._();
  static final JsExtensionService _instance = JsExtensionService._();
  factory JsExtensionService() => _instance;
  static JsExtensionService get instance => _instance;

  final Map<String, JavascriptRuntime> _runtimes = {};
  final Map<String, String> _jsCodes = {};
  final Map<String, List<int>> _packageBytes = {};
  final Map<String, Map<String, dynamic>> _packageManifests = {};

  Future<Map<String, dynamic>?> fetchPackageManifest(
      RegistryEntry entry) async {
    try {
      final response = await http.get(Uri.parse(entry.url), headers: {
        'User-Agent': 'Melodi/5.0',
        'Accept': 'application/octet-stream, */*',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.length < 2)
        return null;
      final bytes = response.bodyBytes;
      if (bytes[0] != 0x50 || bytes[1] != 0x4b) return null;
      _packageBytes[entry.id] = bytes;
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile && file.name == 'manifest.json') {
          final decoded = jsonDecode(utf8.decode(file.content as List<int>));
          if (decoded is Map) {
            final manifest = Map<String, dynamic>.from(decoded);
            _packageManifests[entry.id] = manifest;
            return manifest;
          }
          return null;
        }
      }
    } catch (_) {}
    return null;
  }

  /// .sflx (zip) veya .js dosyasını indir, aç, JS kodunu çıkar
  Future<String> _fetchJsCode(RegistryEntry entry) async {
    if (_jsCodes.containsKey(entry.id)) return _jsCodes[entry.id]!;

    final cachedBytes = _packageBytes[entry.id];
    late final List<int> bytes;
    if (cachedBytes != null) {
      bytes = cachedBytes;
    } else {
      final resp = await http.get(Uri.parse(entry.url), headers: {
        'User-Agent': 'Melodi/5.0',
        'Accept': 'application/octet-stream, application/javascript, */*',
      }).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw Exception('JS bundle indirilemedi: HTTP ${resp.statusCode}');
      }
      bytes = resp.bodyBytes;
      _packageBytes[entry.id] = bytes;
    }
    String jsCode;

    // .sflx ve .8spine zip kontrolü (PK header)
    if (bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final archive = ZipDecoder().decodeBytes(bytes);
      // index.js veya en büyük .js dosyasını bul
      ArchiveFile? jsFile;
      for (final file in archive) {
        if (file.isFile && file.name == 'manifest.json') {
          try {
            final value = jsonDecode(utf8.decode(file.content as List<int>));
            if (value is Map) {
              _packageManifests[entry.id] = Map<String, dynamic>.from(value);
            }
          } catch (_) {}
        }
        if (file.isFile && file.name.endsWith('.js')) {
          if (jsFile == null || file.size > jsFile.size) {
            jsFile = file;
          }
          if (file.name == 'index.js') {
            jsFile = file;
            break;
          }
        }
      }
      if (jsFile == null) {
        throw Exception('Zip içinde .js bulunamadı: ${entry.id}');
      }
      jsCode = utf8.decode(jsFile.content as List<int>);
    } else {
      // Düz .js veya .spotiflac-ext (text)
      jsCode = utf8.decode(bytes, allowMalformed: true);
      // Eğer base64 veya binary ise dene
      if (jsCode.trim().isEmpty || jsCode.contains('\u0000')) {
        jsCode = String.fromCharCodes(bytes);
      }
    }

    _jsCodes[entry.id] = jsCode;
    return jsCode;
  }

  /// Runtime oluştur ve JS kodunu yükle, SpotiFLAC API'sini hazırla
  Future<JavascriptRuntime> _getRuntime(RegistryEntry entry) async {
    if (_runtimes.containsKey(entry.id)) return _runtimes[entry.id]!;

    final jsCode = await _fetchJsCode(entry);
    final runtime = getJavascriptRuntime();

    // Native bridge fonksiyonları
    runtime.onMessage('fetch', (args) async {
      // args: [url, optionsJson]
      try {
        dynamic bridgeArgs = args;
        if (args.length == 1 && args[0] is String) {
          final decoded = jsonDecode(args[0] as String);
          if (decoded is List) bridgeArgs = decoded;
        }
        final url = bridgeArgs[0]?.toString() ?? '';
        final optionsStr =
            bridgeArgs.length > 1 ? bridgeArgs[1]?.toString() ?? '{}' : '{}';
        final options = jsonDecode(optionsStr) as Map<String, dynamic>;
        final method = (options['method']?.toString() ?? 'GET').toUpperCase();
        final headers = (options['headers'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            {};
        final body = options['body']?.toString();

        final uri = Uri.parse(url);
        if (!_isAllowed(entry.permissions, uri)) {
          throw StateError(
              'Eklenti için izin verilmeyen alan adı: ${uri.host}');
        }
        final request = http.Request(method, uri)
          ..headers.addAll(headers.cast<String, String>());
        if (body != null) request.body = body;
        final streamed =
            await request.send().timeout(const Duration(seconds: 20));
        final bytes = await streamed.stream.toBytes();
        return jsonEncode({
          'status': streamed.statusCode,
          'body': utf8.decode(bytes, allowMalformed: true),
          'bodyBase64': base64Encode(bytes),
          'headers': streamed.headers,
        });
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    runtime.onMessage('log', (args) {
      // ignore: avoid_print
      print('[JS ${entry.id}] ${args.join(' ')}');
      return null;
    });

    final settingDefaults = <String, dynamic>{};
    final manifestSettings = _packageManifests[entry.id]?['settings'];
    if (manifestSettings is List) {
      for (final item in manifestSettings.whereType<Map>()) {
        final key = item['key']?.toString();
        if (key != null && key.isNotEmpty)
          settingDefaults[key] = item['default'];
      }
    }
    for (final key in settingDefaults.keys.toList()) {
      final saved = await SecureStorageService.instance
          .read('extension_setting_${entry.id}_$key');
      if (saved == null) continue;
      try {
        settingDefaults[key] = jsonDecode(saved);
      } catch (_) {
        settingDefaults[key] = saved;
      }
    }

    // Official packages use synchronous http.* calls. A cache miss is sent
    // back to Dart; after the verified request completes, the provider call is
    // replayed against the cached response.
    final polyfill = '''
      var module = { exports: {} };
      var exports = module.exports;
      var global = globalThis;
      // SpotiFLAC sözleşmesi: paketler registerExtension({...}) ile kaydolur.
      // Kaydı yakala, global `extension` olarak yayınla ve initialize çağır.
      var __registeredExtension = null;
      function registerExtension(obj) {
        __registeredExtension = obj || {};
        try { globalThis.extension = __registeredExtension; } catch (e) {}
        try { if (__registeredExtension.initialize) __registeredExtension.initialize(__settingDefaults); } catch (e) {}
        return true;
      }
      var __extensionStorage = {};
      var __nativeHttpCache = {};
      var __settingDefaults = ${jsonEncode(settingDefaults)};
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
      Object.keys(__settingDefaults).forEach(function(k){ settings[k] = __settingDefaults[k]; });
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
        input=input.replace(/[^A-Za-z0-9+\/=]/g,'');
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
      function __syncSession(method, path, body, headers) {
        var request = {method:String(method || 'GET').toUpperCase(), path:String(path), body:body == null ? null : body, headers:headers || {}};
        var key = JSON.stringify(request);
        if (__nativeHttpCache['session:' + key] !== undefined) return __nativeHttpCache['session:' + key];
        throw new Error('__MELODI_SESSION__' + btoa(unescape(encodeURIComponent(key))));
      }
      var session = {
        signedFetch:function(method, path, body, headers){ return __syncSession(method, path, body, headers); },
        status:function(){ return {authenticated:true, verification_required:false}; },
        clear:function(){ return true; },
        completeGrant:function(){ return {success:true}; }
      };
      function __syncCrypto(op, value, key) {
        var request = {op:op, value:value, key:key == null ? null : key};
        var cacheKey = 'crypto:' + JSON.stringify(request);
        if (__nativeHttpCache[cacheKey] !== undefined) return __nativeHttpCache[cacheKey];
        throw new Error('__MELODI_CRYPTO__' + btoa(unescape(encodeURIComponent(JSON.stringify(request)))));
      }
      var utils = {
        appUserAgent:function(){ return '${CloudflareSessionService.userAgent}'; },
        randomUserAgent:function(){ return '${CloudflareSessionService.userAgent}'; },
        appVersion:function(){ return '5.0.2'; },
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
        debug:function(){ sendMessage('log', JSON.stringify(Array.from(arguments))); },
        info:function(){ sendMessage('log', JSON.stringify(Array.from(arguments))); },
        warn:function(){ sendMessage('log', JSON.stringify(Array.from(arguments))); },
        error:function(){ sendMessage('log', JSON.stringify(Array.from(arguments))); }
      };
      var console = log;
      // SpotiFLAC paketleri fetch'i EŞZAMANLI kullanır (var res = fetch(...); res.ok).
      // Yanıt önbellekte yoksa replay işaretçisi fırlatılır; Dart isteği yapıp
      // önbelleğe yazar ve betik baştan oynatılır. .json()/.text() düz değer
      // döner: eşzamanlı kullanımda da `await` ile de çalışır.
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

    try {
      runtime.evaluate(polyfill);
      runtime.evaluate(jsCode);
      // registerExtension polyfill içinde yakalandı; global referansı garantile.
      runtime.evaluate(
          'try { if (typeof __registeredExtension !== \'undefined\' && __registeredExtension) { globalThis.extension = __registeredExtension; } } catch (e) {}');
    } catch (e) {
      throw Exception('JS yükleme hatası (${entry.id}): $e');
    }

    _runtimes[entry.id] = runtime;
    return runtime;
  }

  Future<JsEvalResult> _evaluateWithHttpReplay(
    JavascriptRuntime runtime,
    RegistryEntry entry,
    String script,
  ) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final result = await runtime.evaluateAsync(script);
      final raw = result.stringResult;
      final marker =
          RegExp(r'__MELODI_HTTP__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final sessionMarker =
          RegExp(r'__MELODI_SESSION__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final cryptoMarker =
          RegExp(r'__MELODI_CRYPTO__([A-Za-z0-9+/=]+)').firstMatch(raw);
      final fileMarker =
          RegExp(r'__MELODI_FILE__([A-Za-z0-9+/=]+)').firstMatch(raw);
      if (marker == null &&
          sessionMarker == null &&
          cryptoMarker == null &&
          fileMarker == null) {
        return result;
      }

      if (fileMarker != null) {
        final fileRequestJson =
            utf8.decode(base64Decode(fileMarker.group(1)!));
        final fileRequest = jsonDecode(fileRequestJson) as Map<String, dynamic>;
        final fileResponse = await _nativeFileOp(entry, fileRequest);
        runtime.evaluate(
          '__nativeHttpCache[${jsonEncode('file:$fileRequestJson')}] = '
          '${jsonEncode(fileResponse)};',
        );
        continue;
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

      if (sessionMarker != null) {
        final requestJson = utf8.decode(base64Decode(sessionMarker.group(1)!));
        final request = jsonDecode(requestJson) as Map<String, dynamic>;
        final packageManifest = _packageManifests[entry.id] ?? const {};
        final manifest = ExtensionManifest(
          id: entry.id,
          name: entry.name,
          description: entry.description ?? '',
          version: packageManifest['version']?.toString() ??
              entry.version ??
              '1.0.0',
          author: entry.author ?? 'SpotiFLAC',
          kind: entry.kind ?? ExtensionKind.backend,
          baseUrl: 'https://localhost',
          permissions: entry.permissions,
          signedSession: packageManifest['signedSession'] is Map
              ? Map<String, dynamic>.from(
                  packageManifest['signedSession'] as Map)
              : null,
        );
        final response = await SignedSessionService.instance.signedFetch(
          manifest,
          request['method']?.toString() ?? 'GET',
          request['path']?.toString() ?? '/',
          body: request['body'],
          headers: (request['headers'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ) ??
              const {},
        );
        runtime.evaluate(
          '__nativeHttpCache[${jsonEncode('session:$requestJson')}] = '
          '${jsonEncode(response)};',
        );
        continue;
      }

      final requestJson = utf8.decode(base64Decode(marker!.group(1)!));
      final request = jsonDecode(requestJson) as Map<String, dynamic>;
      final uri = Uri.parse(request['url'].toString());
      if (!_isAllowed(entry.permissions, uri)) {
        throw StateError('Eklenti için izin verilmeyen alan adı: ${uri.host}');
      }
      final method = (request['method']?.toString() ?? 'GET').toUpperCase();
      final headers = (request['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString())) ??
          <String, String>{};
      final body = request['body']?.toString();

      late final int statusCode;
      late final List<int> bytes;
      late final Map<String, String> responseHeaders;
      if (method == 'GET' || method == 'POST') {
        final response = method == 'GET'
            ? await CloudflareSessionService.instance.get(uri, headers: headers)
            : await CloudflareSessionService.instance
                .post(uri, headers: headers, body: body);
        statusCode = response.statusCode;
        bytes = response.bodyBytes;
        responseHeaders = response.headers;
      } else {
        final nativeRequest = http.Request(method, uri)
          ..headers.addAll(headers);
        if (body != null) nativeRequest.body = body;
        final response =
            await nativeRequest.send().timeout(const Duration(seconds: 25));
        statusCode = response.statusCode;
        bytes = await response.stream.toBytes();
        responseHeaders = response.headers;
      }
      final responseValue = {
        'statusCode': statusCode,
        'status': statusCode,
        'ok': statusCode >= 200 && statusCode < 300,
        'url': uri.toString(),
        'body': utf8.decode(bytes, allowMalformed: true),
        'bodyBase64': base64Encode(bytes),
        'headers': responseHeaders,
      };
      runtime.evaluate(
        '__nativeHttpCache[${jsonEncode(requestJson)}] = '
        '${jsonEncode(responseValue)};',
      );
    }
    throw StateError('Eklenti çok fazla ardışık ağ isteği oluşturdu');
  }

  bool _isAllowed(List<String> permissions, Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (permissions.isEmpty) return uri.scheme == 'https';
    final host = uri.host.toLowerCase();
    return permissions.any((raw) {
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

  /// SpotiFLAC modülünde arama — JS'deki `search` fonksiyonunu çağırır
  Future<List<Map<String, dynamic>>> search(RegistryEntry entry, String query,
      {int limit = 20}) async {
    final runtime = await _getRuntime(entry);
    final encodedQuery = jsonEncode(query);
    final js = '''
      (async function() {
        try {
          var custom = typeof extension !== 'undefined' && typeof extension.customSearch === 'function' ? extension.customSearch : null;
          if (!custom && typeof customSearch === 'function') custom = customSearch;
          if (!custom && module.exports && typeof module.exports.customSearch === 'function') custom = module.exports.customSearch;
          var fn = typeof search === 'function' ? search : null;
          if (!fn && typeof extension !== 'undefined') fn = extension.searchTracks || extension.search;
          if (!fn && globalThis && typeof globalThis.search === 'function') fn = globalThis.search;
          if (!fn && module.exports && typeof module.exports.search === 'function') fn = module.exports.search;
          if (!fn && typeof exports.search === 'function') fn = exports.search;
          if (!fn && !custom && typeof exports.customSearch === 'function') custom = exports.customSearch;
          if (!fn) {
            // Bazı modüller doğrudan export eder: module.exports = async (q,l) => ...
            if (typeof module !== 'undefined' && typeof module.exports === 'function') fn = module.exports;
          }
          if (!fn && !custom) return JSON.stringify({error: 'search not found'});
          var res = custom
            ? await custom($encodedQuery, {limit:$limit, filter:'tracks', type:'tracks'})
            : await fn($encodedQuery, $limit);
          // Bazı modüller {results:[]} sarmalı döner, bazıları doğrudan dizi
          if (res && typeof res === 'object' && !Array.isArray(res)) res = res.results || res.tracks || res.items || [];
          return JSON.stringify({results: res});
        } catch (e) { return JSON.stringify({error: e.toString() + (e.stack ? " " + e.stack : "")}); }
      })()
    ''';
    final result = await _evaluateWithHttpReplay(runtime, entry, js);
    final str = result.stringResult;
    try {
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      if (decoded.containsKey('error')) throw Exception(decoded['error']);
      final results = decoded['results'] as List? ?? [];
      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('JS search hatası: $e / raw: $str');
    }
  }

  /// SpotiFLAC modülünde stream URL al — JS'deki `getStreamUrl` veya `getUrl`
  Future<String?> getStreamUrl(RegistryEntry entry, String trackId) async {
    final runtime = await _getRuntime(entry);
    final encodedId = jsonEncode(trackId);
    final js = '''
      (async function() {
        try {
          var fn = typeof getStreamUrl === 'function' ? getStreamUrl : null;
          if (!fn && typeof extension !== 'undefined') fn = extension.getStreamUrl || extension.getUrl || extension.getTrackUrl;
          if (!fn && typeof getUrl === 'function') fn = getUrl;
          if (!fn && typeof getTrackUrl === 'function') fn = getTrackUrl;
          if (!fn && globalThis) fn = globalThis.getStreamUrl || globalThis.getUrl || globalThis.getTrackUrl;
          if (!fn && module.exports) fn = module.exports.getStreamUrl || module.exports.getUrl || module.exports.getTrackUrl;
          if (!fn) fn = exports.getStreamUrl || exports.getUrl || exports.getTrackUrl;
          if (!fn) return JSON.stringify({error: 'getStreamUrl not found'});
          var url = await fn($encodedId);
          // Bazı modüller obje döner: {url: "..."} veya doğrudan string
          if (url && typeof url === 'object' && url.url) url = url.url;
          return JSON.stringify({url: url});
        } catch (e) { return JSON.stringify({error: e.toString()}); }
      })()
    ''';
    final result = await _evaluateWithHttpReplay(runtime, entry, js);
    final str = result.stringResult;
    try {
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      if (decoded.containsKey('error')) return null;
      return decoded['url']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// JS `file.*` köprüsünün native karşılığı (senkron replay döngüsünden çağrılır).
  Future<Object?> _nativeFileOp(
      RegistryEntry entry, Map<String, dynamic> req) async {
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
          entry,
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

  /// Eklentinin istediği dosyayı gerçekten indirir (başlık + Range resume destekli).
  /// outputPath boşsa geçici dizine yazar.
  Future<Map<String, dynamic>> _nativeFileDownload(
    RegistryEntry entry,
    String url,
    String outputPath,
    Map<String, dynamic> options,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return {'success': false, 'error': 'bad url'};
    }
    if (!_isAllowed(entry.permissions, uri)) {
      return {'success': false, 'error': 'domain not allowed: ${uri.host}'};
    }
    var path = outputPath.trim();
    if (path.isEmpty) {
      path = await _tempBinPath(entry.id);
    }
    final headers = <String, String>{};
    final optionHeaders = options['headers'];
    if (optionHeaders is Map) {
      optionHeaders.forEach((key, value) {
        if (value != null) headers[key.toString()] = value.toString();
      });
    }
    headers.putIfAbsent(
        'User-Agent',
        () =>
            options['userAgent']?.toString() ??
            CloudflareSessionService.userAgent);
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
      var chunks = 0;
      while (true) {
        if (++chunks > maxChunks || offset >= maxTotalBytes) {
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
        final end =
            chunkSize > 0 ? offset + chunkSize - 1 : null;
        if (offset > 0 || end != null) {
          request.headers.set(HttpHeaders.rangeHeader,
              end != null ? 'bytes=$offset-$end' : 'bytes=$offset-');
        }
        final response =
            await request.close().timeout(const Duration(seconds: 25));
        if (response.statusCode != 200 && response.statusCode != 206) {
          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}'
          };
        }
        final sink = file.openWrite(
            mode: offset > 0 && response.statusCode == 206
                ? FileMode.append
                : FileMode.write);
        if (offset > 0 && response.statusCode == 200) offset = 0;
        try {
          await for (final data
              in response.timeout(const Duration(seconds: 60))) {
            sink.add(data);
            offset += data.length;
            if (offset >= maxTotalBytes) break;
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        final contentLength = response.contentLength;
        // Parça istendiyse ve sunucu aralığı tam verdiyse bitti say.
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

  Future<String> _tempBinPath(String extId) async {
    final tmp = await getTemporaryDirectory();
    final safeId = extId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${tmp.path}/melodi_ext_${safeId}_${DateTime.now().millisecondsSinceEpoch}.bin';
  }

  /// Eklentinin kendi `download()` hattını çalıştırıp gerçek dosyayı indirir.
  /// Önce `checkAvailability` ile videoID eşleşmesi yapılır.
  /// Dönüş: {success, file_path, actual_extension, cover_url, error}
  Future<Map<String, dynamic>?> downloadExtensionFile(
    RegistryEntry entry, {
    required String trackId,
    String title = '',
    String artist = '',
    String quality = 'best',
    required String outputPath,
  }) async {
    final runtime = await _getRuntime(entry);
    final js = '''
      (async function() {
        try {
          var e = (typeof globalThis !== 'undefined' && globalThis.__registeredExtension) ||
            (typeof extension !== 'undefined' ? extension : null) ||
            (typeof module !== 'undefined' ? module.exports : null);
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
    final result = await _evaluateWithHttpReplay(runtime, entry, js);
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

  /// SpotiFLAC download-provider contract. Providers expose
  /// checkAvailability(isrc, title, artist, options) and download(...).
  /// Direct-URL providers can therefore participate in Melodi playback too.
  Future<String?> getProviderUrl(
    RegistryEntry entry,
    Map<String, dynamic> track,
  ) async {
    // Eklenti hattı dosyayı gerçekten indirir; dönen yerel yol oynatma ve
    // kütüphaneye alma için aynen kullanılır (oynatıcı dosyayı çalar).
    final tmp = await _tempBinPath(entry.id);
    final result = await downloadExtensionFile(
      entry,
      trackId: (track['id'] ?? track['trackId'] ?? '').toString(),
      title: (track['title'] ?? '').toString(),
      artist: (track['artist'] ?? '').toString(),
      quality: (track['quality'] ?? 'best').toString(),
      outputPath: tmp,
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

  Future<Map<String, dynamic>?> fetchLyrics(
    RegistryEntry entry, {
    required String title,
    required String artist,
    String? album,
    int? durationMs,
  }) async {
    final runtime = await _getRuntime(entry);
    final args = jsonEncode([
      title,
      artist,
      album ?? '',
      (durationMs ?? 0) / 1000,
    ]);
    final result = await _evaluateWithHttpReplay(runtime, entry, '''
      (async function() {
        try {
          var fn = (typeof extension !== 'undefined' && extension.fetchLyrics) ||
            (module.exports && module.exports.fetchLyrics) || globalThis.fetchLyrics;
          if (typeof fn !== 'function') return JSON.stringify({error:'fetchLyrics not found'});
          var a = $args;
          return JSON.stringify({result: await fn(a[0], a[1], a[2], a[3])});
        } catch(e) { return JSON.stringify({error:String(e)}); }
      })()
    ''');
    try {
      final decoded = jsonDecode(result.stringResult) as Map<String, dynamic>;
      final value = decoded['result'];
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  void dispose(String id) {
    _runtimes[id]?.dispose();
    _runtimes.remove(id);
    _jsCodes.remove(id);
    _packageBytes.remove(id);
    _packageManifests.remove(id);
  }

  void disposeAll() {
    for (final r in _runtimes.values) {
      r.dispose();
    }
    _runtimes.clear();
    _jsCodes.clear();
    _packageBytes.clear();
    _packageManifests.clear();
  }
}
