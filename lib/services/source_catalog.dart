import '../models/extension.dart';
import '../models/source_descriptor.dart';

/// A single source of truth for what each Melodi integration can do.
///
/// UI code consumes these descriptors instead of guessing capabilities from a
/// service name. This keeps unsupported actions hidden and makes new native or
/// extension-backed providers additive.
class SourceCatalog {
  const SourceCatalog._();

  static List<SourceDescriptor> build({
    bool navidromeConnected = false,
    List<InstalledExtension> extensions = const [],
  }) {
    return [
      const SourceDescriptor(
        kind: SourceKind.local,
        name: 'Bu aygıt',
        description: 'İçe aktarılan ve indirilen müzikler',
        status: SourceStatus.available,
        capabilities: {
          SourceCapability.search,
          SourceCapability.playback,
          SourceCapability.library,
          SourceCapability.playlists,
          SourceCapability.likes,
          SourceCapability.lyrics,
          SourceCapability.downloads,
          SourceCapability.lossless,
        },
      ),
      SourceDescriptor(
        kind: SourceKind.navidrome,
        name: 'Navidrome / Subsonic',
        description: 'Kendi sunucundan kayıpsız oynatma ve çevrimdışı indirme',
        status: navidromeConnected
            ? SourceStatus.connected
            : SourceStatus.unavailable,
        requiresAccount: true,
        capabilities: const {
          SourceCapability.search,
          SourceCapability.playback,
          SourceCapability.library,
          SourceCapability.playlists,
          SourceCapability.likes,
          SourceCapability.lyrics,
          SourceCapability.downloads,
          SourceCapability.lossless,
        },
      ),
      const SourceDescriptor(
        kind: SourceKind.youtube,
        name: 'YouTube',
        description: 'Arama ve eşleşen ses akışları',
        status: SourceStatus.available,
        capabilities: {
          SourceCapability.search,
          SourceCapability.playback,
        },
      ),
      const SourceDescriptor(
        kind: SourceKind.deezer,
        name: 'Deezer',
        description: 'Keşif metadatası ve önizlemeler',
        status: SourceStatus.available,
        capabilities: {
          SourceCapability.search,
          SourceCapability.playback,
          SourceCapability.recommendations,
        },
      ),
      const SourceDescriptor(
        kind: SourceKind.jioSaavn,
        name: 'JioSaavn',
        description: 'Arama ve uygun bölgelerde ses akışı',
        status: SourceStatus.available,
        capabilities: {
          SourceCapability.search,
          SourceCapability.playback,
        },
      ),
      // Eklenti mağazasından kurulan topluluk sağlayıcıları.
      for (final extension in extensions)
        if (extension.enabled)
          SourceDescriptor(
            kind: SourceKind.extension,
            name: extension.manifest.name,
            description: extension.manifest.description.isEmpty
                ? 'Topluluk eklentisi · ${extension.manifest.kind.label}'
                : extension.manifest.description,
            status: SourceStatus.available,
            capabilities: _capabilitiesFor(extension.manifest),
          ),
    ];
  }

  static Set<SourceCapability> _capabilitiesFor(ExtensionManifest manifest) {
    final parsed = <SourceCapability>{};
    for (final raw in manifest.capabilities) {
      switch (raw) {
        case 'search':
          parsed.add(SourceCapability.search);
        case 'playback' || 'stream':
          parsed.add(SourceCapability.playback);
        case 'library':
          parsed.add(SourceCapability.library);
        case 'playlists' || 'playlist':
          parsed.add(SourceCapability.playlists);
        case 'likes':
          parsed.add(SourceCapability.likes);
        case 'recommendations':
          parsed.add(SourceCapability.recommendations);
        case 'lyrics':
          parsed.add(SourceCapability.lyrics);
        case 'scrobble':
          parsed.add(SourceCapability.scrobble);
        case 'downloads' || 'download':
          parsed.add(SourceCapability.downloads);
        case 'lossless' || 'flac':
          parsed.add(SourceCapability.lossless);
      }
    }
    switch (manifest.kind) {
      case ExtensionKind.backend:
        parsed.addAll({
          SourceCapability.search,
          SourceCapability.playback,
          SourceCapability.downloads,
        });
      case ExtensionKind.hifi:
        parsed.addAll({
          SourceCapability.search,
          SourceCapability.playback,
          SourceCapability.downloads,
          SourceCapability.lossless,
        });
    }
    return parsed;
  }

}
