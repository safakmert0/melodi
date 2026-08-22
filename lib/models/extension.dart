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

class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.kind,
    required this.baseUrl,
    this.homepage,
    this.minAppVersion,
    this.capabilities = const [],
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final ExtensionKind kind;
  final String baseUrl;
  final String? homepage;
  final String? minAppVersion;
  final List<String> capabilities;

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

    return ExtensionManifest(
      id: id,
      name: name,
      description: json['description']?.toString().trim() ?? '',
      version: versionRaw.isEmpty ? '1.0.0' : versionRaw,
      author: json['author']?.toString().trim() ?? 'Bilinmeyen',
      kind: kind,
      baseUrl: baseUrl,
      homepage: _optionalUrl(json['homepage']),
      minAppVersion: json['minAppVersion']?.toString().trim(),
      capabilities: capabilities,
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
        if (homepage != null) 'homepage': homepage,
        if (minAppVersion != null) 'minAppVersion': minAppVersion,
        'capabilities': capabilities,
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
  });

  final String id;
  final String name;
  final String url;
  final String? version;
  final String? description;
  final ExtensionKind? kind;
  final String? author;

  static RegistryEntry? fromJson(
    Map<dynamic, dynamic> json, {
    String? baseUrl,
  }) {
    final rawUrl =
        (json['url'] ?? json['manifest_url'] ?? json['file'])?.toString().trim() ??
            '';
    final url = _resolveUrl(rawUrl, baseUrl);
    if (url == null) return null;
    final uri = Uri.parse(url);
    var id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      // Dosya adından id türet: extensions/foo.json -> foo
      final segments = uri.pathSegments.where((s) => s.endsWith('.json'));
      id = segments.isEmpty ? '' : segments.last.replaceAll('.json', '');
    }
    if (id.isEmpty) return null;
    return RegistryEntry(
      id: id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), ''),
      name: json['name']?.toString().trim().isNotEmpty ?? false
          ? json['name'].toString().trim()
          : id,
      url: url,
      version: json['version']?.toString().trim(),
      description: json['description']?.toString().trim(),
      kind: ExtensionKindX.tryParse(json['kind']),
      author: json['author']?.toString().trim(),
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
    final rawEntries = decoded['extensions'];
    if (rawEntries is! List) {
      throw const FormatException('registry: "extensions" listesi eksik');
    }
    final entries = <RegistryEntry>[];
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
    return ExtensionRegistry(
      name: decoded['name']?.toString().trim().isNotEmpty ?? false
          ? decoded['name'].toString()
          : repoUrl,
      updatedAt: DateTime.tryParse(decoded['updatedAt']?.toString() ?? ''),
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
