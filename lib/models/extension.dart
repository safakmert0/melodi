/// Melodi eklenti sistemi modelleri.
///
/// Eklentiler declarative JSON manifest'lerdir; çalışma anında kod
/// yüklenmez. Her manifest bir sağlayıcı uç noktası (backend / lossless
/// sunucu) tanımlar. Kullanıcı yalnızca depo (registry) bağlantısını
/// ekler, sunucu adresi girmez.
library;

import 'dart:convert';

/// Eklentinin hedeflediği sağlayıcı türü.
enum ExtensionKind { backend, hifi }

extension ExtensionKindX on ExtensionKind {
  String get wireName => switch (this) {
        ExtensionKind.backend => 'backend',
        ExtensionKind.hifi => 'hifi',
      };

  String get label => switch (this) {
        ExtensionKind.backend => 'yt-dlp Backend',
        ExtensionKind.hifi => 'Lossless Sunucu',
      };

  static ExtensionKind? tryParse(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    if (raw == 'backend') return ExtensionKind.backend;
    if (raw == 'hifi' || raw == 'lossless') return ExtensionKind.hifi;
    return null;
  }
}

/// Eklentinin konuştuğu protokol.
///
/// - [ytdlpBackend]: Melodi'nin kendi FastAPI yt-dlp sunucu sözleşmesi.
/// - [piped]: Herkese açık Piped örneklerinin API sözleşmesi.
enum ExtensionProtocol {
  ytdlpBackend('yt-dlp-backend'),
  piped('piped');

  const ExtensionProtocol(this.wireName);
  final String wireName;

  static ExtensionProtocol? tryParse(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    if (raw == null || raw.isEmpty || raw == ytdlpBackend.wireName) {
      return ExtensionProtocol.ytdlpBackend;
    }
    if (raw == piped.wireName) return ExtensionProtocol.piped;
    return null;
  }
}

class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.kind,
    required this.baseUrl,
    this.protocol = ExtensionProtocol.ytdlpBackend,
    this.homepage,
    this.minAppVersion,
    this.capabilities = const [],
    this.permissions = const [],
    this.requiredRuntimeFeatures = const [],
    this.signedSession,
    this.settings = const [],
    this.healthPath = '/',
    this.healthMethod = 'GET',
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final ExtensionKind kind;
  final String baseUrl;
  final ExtensionProtocol protocol;
  final String? homepage;
  final String? minAppVersion;
  final List<String> capabilities;

  /// SpotiFLAC/DebridMusic tarzı ağ izinleri — boş ise tüm https izinli
  final List<String> permissions;
  final List<String> requiredRuntimeFeatures;
  final Map<String, dynamic>? signedSession;
  final List<Map<String, dynamic>> settings;

  /// Sağlık kontrol yolu, örn. "/" veya "/health"
  final String healthPath;

  /// HEAD veya GET
  final String healthMethod;

  static ExtensionManifest fromJson(Map<dynamic, dynamic> json) {
    final id = _cleanId(json['id']);
    if (id == null) {
      throw const FormatException('manifest: "id" alanı geçersiz');
    }
    final name = json['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      throw const FormatException('manifest: "name" alanı zorunlu');
    }

    final kind = ExtensionKindX.tryParse(json['kind']);
    if (kind == null) {
      throw const FormatException(
          'manifest: "kind" alanı backend veya hifi olmalı');
    }

    final baseUrl = _normalizeBaseUrl(json['baseUrl'] ?? json['base_url']);
    if (baseUrl == null) {
      throw const FormatException(
          'manifest: "baseUrl" geçerli bir http(s) adresi olmalı');
    }

    final versionRaw = json['version']?.toString().trim() ?? '';
    final capabilities = (json['capabilities'] as List? ?? const [])
        .map((c) => c.toString().trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
    final rawPermissions = json['permissions'];
    final permissions = (rawPermissions is Map
            ? rawPermissions['network'] as List? ?? const []
            : rawPermissions as List? ??
                json['network_permissions'] as List? ??
                const [])
        .map((c) => c.toString().trim())
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
    final healthPath = json['health_path']?.toString().trim() ??
        json['healthPath']?.toString().trim() ??
        '/';
    final healthMethod = (json['health_method']?.toString().trim() ??
            json['healthMethod']?.toString().trim() ??
            'GET')
        .toUpperCase();
    final requiredRuntimeFeatures =
        (json['requiredRuntimeFeatures'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false);
    final signedSession = json['signedSession'] is Map
        ? Map<String, dynamic>.from(json['signedSession'] as Map)
        : null;
    final settings = (json['settings'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);

    final protocol = ExtensionProtocol.tryParse(json['protocol']);
    if (json['protocol'] != null && protocol == null) {
      throw const FormatException(
          'manifest: "protocol" alanı yt-dlp-backend veya piped olmalı');
    }

    return ExtensionManifest(
      id: id,
      name: name,
      description: json['description']?.toString().trim() ?? '',
      version: versionRaw.isEmpty ? '1.0.0' : versionRaw,
      author: json['author']?.toString().trim() ?? 'Bilinmeyen',
      kind: kind,
      baseUrl: baseUrl,
      protocol: protocol ?? ExtensionProtocol.ytdlpBackend,
      homepage: _optionalUrl(json['homepage']),
      minAppVersion: json['minAppVersion']?.toString().trim(),
      capabilities: capabilities,
      permissions: permissions,
      requiredRuntimeFeatures: requiredRuntimeFeatures,
      signedSession: signedSession,
      settings: settings,
      healthPath: healthPath.isEmpty ? '/' : healthPath,
      healthMethod: (healthMethod == 'HEAD' ? 'HEAD' : 'GET'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'author': author,
        'kind': kind.wireName,
        'baseUrl': baseUrl,
        'protocol': protocol.wireName,
        if (homepage != null) 'homepage': homepage,
        if (minAppVersion != null) 'minAppVersion': minAppVersion,
        'capabilities': capabilities,
        if (permissions.isNotEmpty) 'permissions': permissions,
        if (requiredRuntimeFeatures.isNotEmpty)
          'requiredRuntimeFeatures': requiredRuntimeFeatures,
        if (signedSession != null) 'signedSession': signedSession,
        if (settings.isNotEmpty) 'settings': settings,
        'health_path': healthPath,
        'health_method': healthMethod,
      };

  static String? _cleanId(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return null;
    final sanitized = raw.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return sanitized.isEmpty ? null : sanitized;
  }

  static String? _normalizeBaseUrl(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return uri.toString().replaceAll(RegExp(r'/+$'), '');
  }

  static String? _optionalUrl(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return null;
    return raw;
  }

  /// SpotiFLAC tarzı ağ izin kontrolü — permissions boşsa tüm https izinli.
  bool isUrlAllowed(String url) {
    if (permissions.isEmpty) return true;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    for (final p in permissions) {
      final allowed = p.toLowerCase();
      if (host == allowed ||
          host.endsWith('.$allowed') ||
          url.toLowerCase().startsWith(allowed)) return true;
    }
    return false;
  }

  /// Health check URL
  String get healthUrl {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = healthPath.startsWith('/') ? healthPath : '/$healthPath';
    return '$base$path';
  }
}

/// Kurulu bir eklentinin durumunu tutar.
class InstalledExtension {
  const InstalledExtension({
    required this.manifest,
    this.enabled = true,
    required this.installedAt,
  });

  final ExtensionManifest manifest;
  final bool enabled;
  final DateTime installedAt;

  InstalledExtension copyWith({bool? enabled}) => InstalledExtension(
        manifest: manifest,
        enabled: enabled ?? this.enabled,
        installedAt: installedAt,
      );

  Map<String, dynamic> toJson() => {
        'manifest': manifest.toJson(),
        'enabled': enabled,
        'installedAt': installedAt.toIso8601String(),
      };

  static InstalledExtension fromJson(Map<dynamic, dynamic> json) {
    final manifestRaw = json['manifest'];
    if (manifestRaw is! Map) {
      throw const FormatException('installed: manifest eksik');
    }
    return InstalledExtension(
      manifest:
          ExtensionManifest.fromJson(Map<dynamic, dynamic>.from(manifestRaw)),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      installedAt: DateTime.tryParse(json['installedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static List<InstalledExtension> listFromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecodeList(raw);
      return decoded
          .map((e) {
            try {
              return InstalledExtension.fromJson(e);
            } on FormatException {
              return null;
            }
          })
          .whereType<InstalledExtension>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Bir depodaki tek eklenti kaydı.
class RegistryEntry {
  const RegistryEntry({
    required this.id,
    required this.name,
    required this.url,
    this.version,
    this.description,
    this.kind,
    this.author,
    this.category,
    this.capabilities = const [],
    this.permissions = const [],
  });

  final String id;
  final String name;
  final String url;
  final String? version;
  final String? description;
  final ExtensionKind? kind;
  final String? author;
  final String? category;
  final List<String> capabilities;
  final List<String> permissions;

  static RegistryEntry? fromJson(
    Map<dynamic, dynamic> json, {
    String? baseUrl,
    String? categoryHint,
  }) {
    // Melodi native: url/manifest_url/file; SpotiFLAC-compat: download_url; 8spine: download/file/pkg (download öncelikli - klasör bilgisi için)
    final rawUrl = (json['url'] ??
                json['manifest_url'] ??
                json['download'] ??
                json['download_url'] ??
                json['file'])
            ?.toString()
            .trim() ??
        '';
    final url = _resolveUrl(rawUrl, baseUrl);
    if (url == null) return null;
    final uri = Uri.parse(url);
    var id = json['id']?.toString().trim() ?? '';
    // 8spine may use pkg as id fallback
    if (id.isEmpty) id = json['pkg']?.toString().trim() ?? '';
    if (id.isEmpty) {
      // Dosya adından id türet: extensions/foo.json -> foo veya .sflx/.8spine/.js için
      final lastSeg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      if (lastSeg.endsWith('.json')) {
        id = lastSeg.replaceAll('.json', '');
      } else if (lastSeg.endsWith('.sflx')) {
        id = lastSeg.replaceAll('.sflx', '');
      } else if (lastSeg.endsWith('.spotiflac-ext')) {
        id = lastSeg.replaceAll('.spotiflac-ext', '');
      } else if (lastSeg.endsWith('.8spine')) {
        id = lastSeg.replaceAll('.8spine', '');
      } else if (lastSeg.endsWith('.js')) {
        id = lastSeg.replaceAll('.js', '');
      } else {
        final segs = uri.pathSegments.where((s) => s.endsWith('.json'));
        id = segs.isEmpty ? '' : segs.last.replaceAll('.json', '');
      }
    }
    if (id.isEmpty) return null;
    // name: display_name (SpotiFLAC) öncelikli, yoksa name
    final displayName = json['display_name']?.toString().trim() ?? '';
    final rawName = (displayName.isNotEmpty
        ? displayName
        : json['name']?.toString().trim() ?? '');
    // kind: Melodi kind yoksa SpotiFLAC category veya 8spine tags/categoryHint'den türet
    var kind = ExtensionKindX.tryParse(json['kind']);
    if (kind == null) {
      final cat = json['category']?.toString().trim().toLowerCase();
      if (cat == 'download') {
        kind = ExtensionKind.hifi;
      } else if (cat == 'integration')
        kind = ExtensionKind.backend;
      else if (categoryHint != null) {
        final hint = categoryHint.toLowerCase();
        if (hint.contains('hifi') ||
            hint.contains('lossless') ||
            hint.contains('debrid')) {
          kind = ExtensionKind.hifi;
        } else if (hint.contains('artwork')) {
          kind = ExtensionKind.backend;
        } else if (hint.contains('geolier') ||
            hint.contains('livie') ||
            hint.contains('ricky')) {
          kind = ExtensionKind.hifi;
        }
      }
      // Fallback via tags/type/folder heuristics (8spine)
      if (kind == null) {
        final tags = (json['tags'] as List? ?? const [])
            .map((e) => e.toString().toLowerCase())
            .toList();
        final type = json['type']?.toString().toLowerCase() ?? '';
        final folder = json['folder']?.toString().toLowerCase() ?? '';
        final desc = json['description']?.toString().toLowerCase() ?? '';
        final hasLossless = tags.any((t) =>
                t.contains('lossless') ||
                t.contains('hi-res') ||
                t.contains('flac') ||
                t.contains('hires')) ||
            desc.contains('lossless') ||
            desc.contains('hi-res') ||
            desc.contains('flac') ||
            type == 'module' &&
                (tags.contains('qobuz') ||
                    tags.contains('tidal') ||
                    tags.contains('deezer'));
        if (hasLossless) {
          kind = ExtensionKind.hifi;
        } else if (folder == 'modules' || type == 'module')
          kind = ExtensionKind.backend;
        else if (type == 'artwork') kind = ExtensionKind.backend;
      }
    }
    return RegistryEntry(
      id: id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), ''),
      name: rawName.isNotEmpty ? rawName : id,
      url: url,
      version: (json['version'] ?? json['code'])?.toString().trim(),
      description: json['description']?.toString().trim(),
      kind: kind,
      author: json['author']?.toString().trim(),
      category:
          (json['category'] ?? json['type'])?.toString().trim().toLowerCase(),
      capabilities: (json['capabilities'] as List? ?? const [])
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      permissions: (json['permissions'] is Map
              ? ((json['permissions'] as Map)['network'] as List? ?? const [])
              : json['permissions'] as List? ?? const [])
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Mutlak http(s) adresi ya da depo adresine göreli yol kabul eder.
  static String? _resolveUrl(String raw, String? baseUrl) {
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'https' || uri.scheme == 'http') return uri.toString();
      return null;
    }
    if (baseUrl == null) return null;
    try {
      final resolved = Uri.parse(baseUrl).resolve(raw);
      if (resolved.scheme == 'https' || resolved.scheme == 'http') {
        return resolved.toString();
      }
    } catch (_) {}
    return null;
  }
}

/// İndirilmiş bir depo (registry.json) anlık görüntüsü.
class RepoSnapshot {
  const RepoSnapshot({
    required this.url,
    this.registry,
    this.error,
  });

  final String url;
  final ExtensionRegistry? registry;
  final String? error;

  bool get hasError => error != null;
}

/// registry.json belgesi.
class ExtensionRegistry {
  const ExtensionRegistry({
    required this.name,
    required this.entries,
    this.updatedAt,
  });

  final String name;
  final List<RegistryEntry> entries;
  final DateTime? updatedAt;

  static ExtensionRegistry parse(String body, String repoUrl) {
    final decoded = jsonDecodeMap(body);
    final entries = <RegistryEntry>[];
    // 1) Melodi / SpotiFLAC native: decoded['extensions'] is List
    final rawEntries = decoded['extensions'];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is! Map) continue;
        final entry = RegistryEntry.fromJson(
          Map<dynamic, dynamic>.from(item),
          baseUrl: repoUrl,
        );
        if (entry != null && !entries.any((e) => e.id == entry.id)) {
          entries.add(entry);
        }
      }
    } else {
      // 2) Generic: aggregate all category:* and other module lists (8spine etc)
      // 8spine uses keys like "category:modules", "category:geolier_modules", etc.
      // Future registries may use any shape — collect any List that looks like modules.
      for (final kv in decoded.entries) {
        final key = kv.key.toString();
        final val = kv.value;
        if (val is! List) continue;
        // Skip known non-module lists
        if (key == 'external_sources' ||
            key == 'generated_at' ||
            key == 'updated_at' ||
            key == 'updatedAt' ||
            key == 'version' ||
            key == 'name') continue;
        // Heuristic: category:* or any list containing maps with id/pkg/download
        final isCategory = key.startsWith('category:');
        final sampleHasModuleShape = val.isNotEmpty &&
            val.first is Map &&
            ((val.first as Map).containsKey('id') ||
                (val.first as Map).containsKey('pkg'));
        if (!isCategory && !sampleHasModuleShape) {
          // For generic future registries, also try if list contains module-like maps
          final anyModuleLike = val.any((e) =>
              e is Map &&
              (e.containsKey('download') ||
                  e.containsKey('file') ||
                  e.containsKey('pkg') ||
                  e.containsKey('url')));
          if (!anyModuleLike) continue;
        }
        for (final item in val) {
          if (item is! Map) continue;
          final entry = RegistryEntry.fromJson(
            Map<dynamic, dynamic>.from(item),
            baseUrl: repoUrl,
            categoryHint: key,
          );
          if (entry != null && !entries.any((e) => e.id == entry.id)) {
            entries.add(entry);
          }
        }
      }
      // If still empty, throw to surface error
      if (entries.isEmpty) {
        // Check if external_sources exists — treat as valid but empty registry (user will see external sources)
        if (decoded.containsKey('external_sources')) {
          // keep empty but not error
        } else {
          throw const FormatException('registry: "extensions" listesi eksik');
        }
      }
    }
    // name: Melodi 'name' veya SpotiFLAC kök 'version' fallback veya 8spine host
    final rawName = decoded['name']?.toString().trim() ??
        (decoded['version'] != null ? 'SpotiFLAC Registry' : null) ??
        (decoded['generated_at'] != null ? '8spine Registry' : null);
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : Uri.tryParse(repoUrl)?.host ?? repoUrl;
    // updatedAt: camel, snake, generated_at
    final updatedAtRaw = decoded['updatedAt']?.toString() ??
        decoded['updated_at']?.toString() ??
        decoded['generated_at']?.toString() ??
        '';
    return ExtensionRegistry(
      name: name,
      updatedAt: DateTime.tryParse(updatedAtRaw),
      entries: entries,
    );
  }
}

// ---------------------------------------------------------------------------
// JSON yardımcıları
// ---------------------------------------------------------------------------

List<Map<dynamic, dynamic>> jsonDecodeList(String raw) {
  final value = jsonDecode(raw);
  if (value is! List) throw const FormatException('Beklenen liste');
  return value.whereType<Map>().toList();
}

Map<dynamic, dynamic> jsonDecodeMap(String raw) {
  final value = jsonDecode(raw);
  if (value is! Map) throw const FormatException('Beklenen nesne');
  return value;
}
