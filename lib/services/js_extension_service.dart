import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;
import '../models/extension.dart';
import 'cloudflare_session_service.dart';
import 'signed_session_service.dart';
import 'secure_storage_service.dart';

/// SpotiFLAC için JS sandbox — .sflx (zip) içindeki index.js'yi quickjs'de çalıştırır.
/// 8spine için native Dart portu ayrıdır (B), bu servis sadece SpotiFLAC (A) içindir.
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
      var file = {
        exists:function(){ return false; },
        delete:function(){ return true; },
        download:function(url){ return {success:true, path:String(url), url:String(url)}; },
        downloadChunked:function(url){ return {success:true, path:String(url), url:String(url)}; },
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
      function fetch(url, options) {
        return new Promise(function(resolve, reject) {
          sendMessage('fetch', JSON.stringify([url, JSON.stringify(options || {})])).then(function(resStr) {
            var res = JSON.parse(resStr);
            if (res.error) reject(res.error);
            else resolve({
              status: res.status,
              ok: res.status >= 200 && res.status < 300,
              text: function() { return Promise.resolve(res.body); },
              json: function() { return Promise.resolve(JSON.parse(res.body)); },
              arrayBuffer: function() { return Promise.resolve(res.bodyBase64); },
              headers: res.headers
            });
          });
        });
      }
    ''';

    try {
      runtime.evaluate(polyfill);
      runtime.evaluate(jsCode);
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
      if (marker == null && sessionMarker == null && cryptoMarker == null) {
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

  /// SpotiFLAC download-provider contract. Providers expose
  /// checkAvailability(isrc, title, artist, options) and download(...).
  /// Direct-URL providers can therefore participate in Melodi playback too.
  Future<String?> getProviderUrl(
    RegistryEntry entry,
    Map<String, dynamic> track,
  ) async {
    final runtime = await _getRuntime(entry);
    final input = jsonEncode(track);
    final js = '''
      (async function() {
        try {
          var e = typeof extension !== 'undefined' ? extension : (module.exports || exports || globalThis);
          var check = e.checkAvailability || globalThis.checkAvailability;
          var download = e.download || globalThis.download;
          if (typeof download !== 'function') return JSON.stringify({error:'download not found'});
          var t = $input;
          var prepared = null;
          if (typeof check === 'function') {
            var availability = await check(t.isrc || '', t.title || '', t.artist || '', {});
            if (availability === false || (availability && availability.available === false)) {
              return JSON.stringify({error:'unavailable'});
            }
            if (availability && typeof availability === 'object') {
              prepared = availability.preparedContext || availability.context || availability;
            }
          }
          var result = await download(
            t.id || t.trackId || '',
            t.quality || 'LOSSLESS',
            '',
            function() {},
            { preparedContext: prepared, track: t }
          );
          if (typeof result === 'string') return JSON.stringify({url:result});
          result = result || {};
          return JSON.stringify({url:result.url || result.streamUrl || result.downloadUrl || result.fileUrl || result.file_path || result.filePath || result.path});
        } catch (e) { return JSON.stringify({error:String(e)}); }
      })()
    ''';

    final result = await _evaluateWithHttpReplay(runtime, entry, js);
    try {
      final decoded = jsonDecode(result.stringResult) as Map<String, dynamic>;
      return decoded['url']?.toString();
    } catch (_) {
      return null;
    }
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
