import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/extension.dart';
import 'database_service.dart';

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
  static const Duration _timeout = Duration(seconds: 15);

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
        _repos = [officialRepoUrl];
        await _persistRepos();
      }
    } catch (_) {
      _repos = [officialRepoUrl];
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
  Future<String?> resolveEndpoint(ExtensionKind kind) async {
    await ensureLoaded();
    for (final ext in _installed) {
      if (ext.enabled && ext.manifest.kind == kind) {
        return ext.manifest.baseUrl;
      }
    }
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
      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return RepoSnapshot(
            url: url, error: 'HTTP ${response.statusCode}');
      }
      return RepoSnapshot(
        url: url,
        registry: ExtensionRegistry.parse(response.body, url),
      );
    } on TimeoutException {
      return RepoSnapshot(url: url, error: 'Zaman aşımı');
    } catch (e) {
      debugPrint('Extension repo error ($url): $e');
      return RepoSnapshot(url: url, error: 'Depoya erişilemedi');
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
    if (_repos.isEmpty) _repos = [officialRepoUrl];
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
  Future<void> installFromEntry(RegistryEntry entry) async {
    final manifest = await fetchManifest(entry.url);
    await installManifest(manifest);
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
