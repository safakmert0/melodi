import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/extension_service.dart';
import '../models/extension.dart';

/// SpotiFLAC için JS sandbox — .sflx (zip) içindeki index.js'yi quickjs'de çalıştırır.
/// 8spine için native Dart portu ayrıdır (B), bu servis sadece SpotiFLAC (A) içindir.
class JsExtensionService {
  JsExtensionService._();
  static final JsExtensionService _instance = JsExtensionService._();
  factory JsExtensionService() => _instance;
  static JsExtensionService get instance => _instance;

  final Map<String, JavascriptRuntime> _runtimes = {};
  final Map<String, String> _jsCodes = {};

  /// .sflx (zip) veya .js dosyasını indir, aç, JS kodunu çıkar
  Future<String> _fetchJsCode(RegistryEntry entry) async {
    if (_jsCodes.containsKey(entry.id)) return _jsCodes[entry.id]!;

    final resp = await http.get(Uri.parse(entry.url), headers: {
      'User-Agent': 'Melodi/1.0',
      'Accept': 'application/octet-stream, application/javascript, */*',
    }).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('JS bundle indirilemedi: HTTP ${resp.statusCode}');
    }

    final bytes = resp.bodyBytes;
    String jsCode;

    // .sflx ve .8spine zip kontrolü (PK header)
    if (bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final archive = ZipDecoder().decodeBytes(bytes);
      // index.js veya en büyük .js dosyasını bul
      ArchiveFile? jsFile;
      for (final file in archive) {
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
        final url = args[0]?.toString() ?? '';
        final optionsStr = args.length > 1 ? args[1]?.toString() ?? '{}' : '{}';
        final options = jsonDecode(optionsStr) as Map<String, dynamic>;
        final method = (options['method']?.toString() ?? 'GET').toUpperCase();
        final headers = (options['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
        final body = options['body']?.toString();

        final uri = Uri.parse(url);
        http.Response resp;
        if (method == 'POST') {
          resp = await http.post(uri, headers: headers.cast<String, String>(), body: body).timeout(const Duration(seconds: 15));
        } else {
          resp = await http.get(uri, headers: headers.cast<String, String>()).timeout(const Duration(seconds: 15));
        }
        return jsonEncode({'status': resp.statusCode, 'body': resp.body, 'headers': resp.headers});
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    runtime.onMessage('log', (args) {
      // ignore: avoid_print
      print('[JS ${entry.id}] ${args.join(' ')}');
      return null;
    });

    // Global fetch polyfill ve console
    const polyfill = '''
      var console = { log: function() { sendMessage('log', JSON.stringify(Array.from(arguments))); } };
      function fetch(url, options) {
        return new Promise(function(resolve, reject) {
          sendMessage('fetch', JSON.stringify([url, JSON.stringify(options || {})])).then(function(resStr) {
            var res = JSON.parse(resStr);
            if (res.error) reject(res.error);
            else resolve({ status: res.status, text: function() { return Promise.resolve(res.body); }, json: function() { return Promise.resolve(JSON.parse(res.body)); }, headers: res.headers });
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

  /// SpotiFLAC modülünde arama — JS'deki `search` fonksiyonunu çağırır
  Future<List<Map<String, dynamic>>> search(RegistryEntry entry, String query, {int limit = 20}) async {
    final runtime = await _getRuntime(entry);
    final js = '''
      (async function() {
        try {
          var fn = (typeof search !== 'undefined' ? search : (typeof module !== 'undefined' && module.exports && module.exports.search ? module.exports.search : null));
          if (!fn) return JSON.stringify({error: 'search not found'});
          var res = await fn("$query", $limit);
          return JSON.stringify({results: res});
        } catch (e) { return JSON.stringify({error: e.toString()}); }
      })()
    ''';
    final result = await runtime.evaluateAsync(js);
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
    final js = '''
      (async function() {
        try {
          var fn = (typeof getStreamUrl !== 'undefined' ? getStreamUrl : (typeof getUrl !== 'undefined' ? getUrl : (typeof module !== 'undefined' && module.exports ? (module.exports.getStreamUrl || module.exports.getUrl) : null)));
          if (!fn) return JSON.stringify({error: 'getStreamUrl not found'});
          var url = await fn("$trackId");
          return JSON.stringify({url: url});
        } catch (e) { return JSON.stringify({error: e.toString()}); }
      })()
    ''';
    final result = await runtime.evaluateAsync(js);
    final str = result.stringResult;
    try {
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      if (decoded.containsKey('error')) return null;
      return decoded['url']?.toString();
    } catch (_) {
      return null;
    }
  }

  void dispose(String id) {
    _runtimes[id]?.dispose();
    _runtimes.remove(id);
    _jsCodes.remove(id);
  }

  void disposeAll() {
    for (final r in _runtimes.values) {
      r.dispose();
    }
    _runtimes.clear();
    _jsCodes.clear();
  }
}
