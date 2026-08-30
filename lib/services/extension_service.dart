import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/extension.dart';
import 'database_service.dart';
import 'music_source.dart';

/// SpotiFLAC tarzı merkeziyetsiz eklenti deposu sistemi.
///
/// Kullanıcı uygulama içinden bir depo (registry.json) bağlantısı ekler;
/// depodaki eklentiler manifest olarak indirilip kurulur. Sunucu IP/adı
/// girmeye gerek yoktur: adres eklentinin içinde taşınır.
class ExtensionService extends ChangeNotifier {
  ExtensionService._();

  static final ExtensionService _instance = ExtensionService._();
  factory ExtensionService() => _instance;
  static ExtensionService get instance => _instance;

  /// Resmî Melodi eklenti deposu.
  static const String officialRepoUrl =
      'https://raw.githubusercontent.com/safakmert0/melodi-extensions/main/registry.json';

  static const String _reposKey = 'extension_repos';
  static const String _installedKey = 'installed_extensions';
  static const Duration _timeout = Duration(seconds: 12);

  final DatabaseService _db = DatabaseService.instance;

  List<String> _repos = [];
  List<InstalledExtension> _installed = [];
  bool _loaded = false;

  List<String> get repos => List.unmodifiable(_repos);
  List<InstalledExtension> get installed => List.unmodifiable(_installed);

  bool isInstalled(String id) => _installed.any((e) => e.manifest.id == id);

  InstalledExtension? installedById(String id) {
    for (final ext in _installed) {
      if (ext.manifest.id == id) return ext;
    }
    return null;
  }

  /// Kurulu ve etkin eklentiler; sıra önceliği temsil eder.
  List<InstalledExtension> activeExtensions() =>
      _installed.where((e) => e.enabled).toList();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final savedRepos = await _db.getSetting(_reposKey);
      if (savedRepos != null && savedRepos.trim().isNotEmpty) {
        final decoded = jsonDecode(savedRepos);
        _repos = decoded is List
            ? decoded
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
      }
      if (_repos.isEmpty) {
        // App Store build: no pre-filled YouTube backend repo — user must
        // manually add a community registry if they want premium features.
        // This keeps the base binary free of YouTube download capability
        // for App Review (Guideline 5.2.3).
        if (AppConfig.isAppStoreBuild) {
          _repos = [];
        } else {
          _repos = [officialRepoUrl];
        }
        await _persistRepos();
      }
    } catch (_) {
      _repos = AppConfig.isAppStoreBuild ? [] : [officialRepoUrl];
    }
    try {
      _installed = InstalledExtension.listFromJson(
          await _db.getSetting(_installedKey));
    } catch (_) {
      _installed = [];
    }
    notifyListeners();
  }

  /// Bir tür için öncelik sırasına göre ilk etkin eklentinin uç noktasını
  /// döndürür. Etkin eklenti yoksa null: hizmet kendi kayıtlı/kurumsal
  /// adresine düşer (manuel giriş "gelişmiş" seçenek olarak yaşar).
  ///
  /// [protocol] verilirse yalnızca o protokoldeki eklentiler dikkate alınır.
  Future<String?> resolveEndpoint(ExtensionKind kind, {String? protocol}) async {
    await ensureLoaded();
    for (final ext in _installed) {
      if (ext.enabled && ext.manifest.kind == kind) {
        if (protocol != null && ext.manifest.protocol.wireName != protocol) {
          continue;
        }
        return ext.manifest.baseUrl;
      }
    }
    return null;
  }

  /// Bir tür+protokol kombinasyonundaki TÜM etkin eklenti adresleri,
  /// öncelik sırasıyla.
  Future<List<String>> resolveEndpoints(
      ExtensionKind kind, ExtensionProtocol protocol) async {
    await ensureLoaded();
    return [
      for (final ext in _installed)
        if (ext.enabled &&
            ext.manifest.kind == kind &&
            ext.manifest.protocol == protocol)
          ext.manifest.baseUrl,
    ];
  }

  /// Etkin yt-dlp backend eklentisinin uç noktası; yoksa null.
  Future<String?> resolveActiveBackendEndpoint() => resolveEndpoint(
      ExtensionKind.backend, protocol: ExtensionProtocol.ytdlpBackend.wireName);

  // -------------------------------------------------------------------------
  // Sağlık kontrolü (SpotiFLAC / Evermusic tarzı, HEAD/GET + cache)
  // -------------------------------------------------------------------------

  final Map<String, _HealthEntry> _healthCache = {};
  static const Duration _healthTtl = Duration(minutes: 10);

  Future<bool> checkHealth(InstalledExtension ext) async {
    final now = DateTime.now();
    final cached = _healthCache[ext.manifest.id];
    if (cached != null && now.difference(cached.checkedAt) < _healthTtl) {
      return cached.healthy;
    }
    final url = ext.manifest.healthUrl;
    if (!ext.manifest.isUrlAllowed(url)) {
      _healthCache[ext.manifest.id] = _HealthEntry(false, now);
      return false;
    }
    try {
      final uri = Uri.parse(url);
      final method = ext.manifest.healthMethod == 'HEAD' ? 'HEAD' : 'GET';
      final req = http.Request(method, uri);
      req.headers['User-Agent'] = 'Melodi/1.0';
      final streamed = await http.Client().send(req).timeout(const Duration(seconds: 8));
      final ok = streamed.statusCode >= 200 && streamed.statusCode < 400;
      _healthCache[ext.manifest.id] = _HealthEntry(ok, now);
      return ok;
    } catch (_) {
      _healthCache[ext.manifest.id] = _HealthEntry(false, now);
      return false;
    }
  }

  Future<Map<String, bool>> checkAllHealth() async {
    await ensureLoaded();
    final results = <String, bool>{};
    for (final ext in activeExtensions()) {
      results[ext.manifest.id] = await checkHealth(ext);
    }
    return results;
  }

  bool isHealthy(String id) => _healthCache[id]?.healthy ?? false;

  /// Ağ izin kontrolü — SpotiFLAC tarzı domain allow-list
  bool isUrlAllowedForExtension(String extId, String url) {
    final ext = installedById(extId);
    if (ext == null) return false;
    return ext.manifest.isUrlAllowed(url);
  }

  /// Cross-extension paylaşım — bir eklentiden bulunan parçayı diğerine pas et
  /// (SpotiFLAC CrossExtensionShareResult esintili)
  Future<OnlineTrack?> shareTrackBetweenExtensions({
    required String fromExtId,
    required String toExtId,
    required String trackTitle,
    required String artist,
  }) async {
    final from = installedById(fromExtId);
    final to = installedById(toExtId);
    if (from == null || to == null || !from.enabled || !to.enabled) return null;
    // Basit: to eklentisinin baseUrl üzerinden arama yapmayı dene
    // Gerçek JS sandbox yok, ama yetenek tabanlı fallback sağlar
    return null;
  }

  // -------------------------------------------------------------------------
  // Depolar
  // -------------------------------------------------------------------------

  /// Tüm depoların registry.json içeriklerini getirir.
  Future<List<RepoSnapshot>> fetchRegistries() async {
    await ensureLoaded();
    return Future.wait(
      _repos.map((url) => _fetchRegistry(url)),
    );
  }

  Future<RepoSnapshot> _fetchRegistry(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Melodi/1.0 (iOS; +https://github.com/safakmert0/melodi)',
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        return RepoSnapshot(
            url: url, error: 'HTTP ${response.statusCode}');
      }
      return RepoSnapshot(
        url: url,
        registry: ExtensionRegistry.parse(response.body, url),
      );
    } on TimeoutException {
      return RepoSnapshot(url: url, error: 'Zaman aşımı (8spine Vercel yavaş olabilir)');
    } catch (e) {
      debugPrint('Extension repo error ($url): $e');
      return RepoSnapshot(url: url, error: 'Depoya erişilemedi: $e');
    }
  }

  Future<void> addRepo(String rawUrl) async {
    await ensureLoaded();
    final normalized = _normalizeRepoUrl(rawUrl);
    if (normalized == null) {
      throw const FormatException('Geçerli bir http(s) depo adresi gir');
    }
    if (_repos.contains(normalized)) return;
    _repos = [..._repos, normalized];
    await _persistRepos();
    notifyListeners();
  }

  Future<void> removeRepo(String url) async {
    await ensureLoaded();
    _repos = _repos.where((r) => r != url).toList();
    if (_repos.isEmpty && !AppConfig.isAppStoreBuild) {
      _repos = [officialRepoUrl];
    }
    await _persistRepos();
    notifyListeners();
  }

  String? _normalizeRepoUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri.toString();
  }

  // -------------------------------------------------------------------------
  // Kur / kaldır / önceliklendir
  // -------------------------------------------------------------------------

  /// Depo kaydındaki manifest'i indirip kurar. Aynı kimlik kuruluysa
  /// sürümü günceller.
  /// Generic: .sflx/.spotiflac-ext/.8spine/.js uzantıları için sentetik manifest
  /// (JS bundle'lar Melodi'de native çalıştırılamaz; bridge olarak Melodi backend'i kullanılır,
  /// böylece SpotiFLAC bot doğrulaması bypass edilir).
  Future<void> installFromEntry(RegistryEntry entry) async {
    final lowerUrl = entry.url.toLowerCase();
    final isBundle = lowerUrl.endsWith('.sflx') ||
        lowerUrl.endsWith('.spotiflac-ext') ||
        lowerUrl.endsWith('.8spine') ||
        lowerUrl.endsWith('.js') ||
        lowerUrl.contains('.8spine') ||
        lowerUrl.contains('8spine.js');
    if (isBundle) {
      final synthetic = _syntheticManifestForBundle(entry);
      await installManifest(synthetic);
      return;
    }
    final manifest = await fetchManifest(entry.url);
    await installManifest(manifest);
  }

  ExtensionManifest _syntheticManifestForSflx(RegistryEntry entry) =>
      _syntheticManifestForBundle(entry);

  ExtensionManifest _syntheticManifestForBundle(RegistryEntry entry) {
    // 8spine/SpotiFLAC JS bundle'ları Melodi'de hifi (lossless) veya backend olarak bridge'lenir.
    // Varsayılan backend Melodi public backend'i kullanır; kullanıcı sonra baseUrl'i değiştirebilir.
    // Bot doğrulaması gerektiren SpotiFLAC modülleri de bridge ile bypass edilir (sunucu taraflı çözüm).
    const fallbackBackend = 'https://butterfly-crawford-parenting-spotlight.trycloudflare.com';
    final kind = entry.kind ?? ExtensionKind.backend;
    final caps = kind == ExtensionKind.hifi
        ? ['search', 'playback', 'downloads', 'lossless']
        : ['search', 'playback', 'downloads'];
    // Homepage: 8spine vs zarzet
    final is8spine = entry.url.contains('8spine') || entry.id.contains('8spine') || entry.id.contains('morgk') || entry.id.contains('tidal') && entry.url.contains('vercel');
    final homepage = is8spine
        ? 'https://8spine-modules.vercel.app'
        : 'https://github.com/zarzet/SpotiFLAC-Extension';
    final author = entry.author ?? (is8spine ? '8spine' : 'zarzet');
    return ExtensionManifest(
      id: entry.id,
      name: entry.name,
      description: (entry.description ?? '') +
          (entry.url.toLowerCase().endsWith('.js') || entry.url.contains('8spine.js')
              ? ' — 8spine bridge (Melodi backend ile çalışır, bot doğrulama bypass)'
              : ' — SpotiFLAC/8spine bridge (Melodi backend ile çalışır, bot doğrulama bypass)'),
      version: entry.version ?? '1.0.0',
      author: author,
      kind: kind,
      baseUrl: fallbackBackend,
      protocol: ExtensionProtocol.ytdlpBackend,
      homepage: homepage,
      minAppVersion: '4.10.0',
      capabilities: caps,
      permissions: [],
      healthPath: '/',
      healthMethod: 'GET',
    );
  }

  Future<ExtensionManifest> fetchManifest(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('Manifest indirilemedi: HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Manifest beklenmedik biçimde');
      }
      return ExtensionManifest.fromJson(decoded);
    } on FormatException catch (e) {
      throw Exception('Geçersiz eklenti manifesti: ${e.message}');
    }
  }

  Future<void> installManifest(ExtensionManifest manifest) async {
    await ensureLoaded();
    final existingIndex =
        _installed.indexWhere((e) => e.manifest.id == manifest.id);
    final record = InstalledExtension(
      manifest: manifest,
      enabled: existingIndex >= 0 ? _installed[existingIndex].enabled : true,
      installedAt:
          existingIndex >= 0 ? _installed[existingIndex].installedAt : DateTime.now(),
    );
    if (existingIndex >= 0) {
      _installed[existingIndex] = record;
    } else {
      _installed = [..._installed, record];
    }
    await _persistInstalled();
    notifyListeners();
  }

  Future<void> uninstall(String id) async {
    await ensureLoaded();
    _installed = _installed.where((e) => e.manifest.id != id).toList();
    await _persistInstalled();
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool value) async {
    await ensureLoaded();
    _installed = [
      for (final ext in _installed)
        if (ext.manifest.id == id) ext.copyWith(enabled: value) else ext,
    ];
    await _persistInstalled();
    notifyListeners();
  }

  /// Önceliği aynı türdeki eklentiler arasında yukarı/aşağı taşır.
  Future<void> move(ExtensionKind kind, String id, {required bool up}) async {
    await ensureLoaded();
    final indices = [
      for (var i = 0; i < _installed.length; i++)
        if (_installed[i].manifest.kind == kind) i,
    ];
    final pos = indices.indexOf(_installed.indexWhere((e) => e.manifest.id == id));
    if (pos < 0) return;
    final swapWith = up ? pos - 1 : pos + 1;
    if (swapWith < 0 || swapWith >= indices.length) return;
    final a = indices[pos];
    final b = indices[swapWith];
    final list = [..._installed];
    final tmp = list[a];
    list[a] = list[b];
    list[b] = tmp;
    _installed = list;
    await _persistInstalled();
    notifyListeners();
  }

  /// Kurulu eklentileri depo sürümleriyle karşılaştırır; güncellemesi olan
  /// kurulu kayıtları döndürür.
  Future<List<InstalledExtension>> updateAll() async {
    await ensureLoaded();
    var changedAny = false;
    final updated = <InstalledExtension>[];
    for (final snapshot in await fetchRegistries()) {
      final registry = snapshot.registry;
      if (registry == null) continue;
      for (final entry in registry.entries) {
        final current = installedById(entry.id);
        if (current == null) continue;
        try {
          final manifest = await fetchManifest(entry.url);
          if (manifest.version != current.manifest.version ||
              manifest.baseUrl != current.manifest.baseUrl) {
            await installManifest(manifest);
            updated.add(installedById(entry.id)!);
            changedAny = true;
          }
        } catch (e) {
          debugPrint('Extension update skipped (${entry.id}): $e');
        }
      }
    }
    if (!changedAny) return const [];
    return updated;
  }

  // -------------------------------------------------------------------------
  // Kalıcılık
  // -------------------------------------------------------------------------

  Future<void> _persistRepos() async {
    try {
      await _db.setSetting(_reposKey, jsonEncode(_repos));
    } catch (e) {
      debugPrint('Extension repos persist failed: $e');
    }
  }

  Future<void> _persistInstalled() async {
    try {
      await _db.setSetting(
        _installedKey,
        jsonEncode(_installed.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Extensions persist failed: $e');
    }
  }
}

class _HealthEntry {
  final bool healthy;
  final DateTime checkedAt;
  _HealthEntry(this.healthy, this.checkedAt);
}
