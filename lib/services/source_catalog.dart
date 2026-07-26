import '../models/source_descriptor.dart';

/// A single source of truth for what each Melodi integration can do.
///
/// UI code consumes these descriptors instead of guessing capabilities from a
/// service name. This keeps unsupported actions hidden and makes new native or
/// extension-backed providers additive.
class SourceCatalog {
  const SourceCatalog._();

  static List<SourceDescriptor> build({
    required bool spotifyConnected,
    required bool youtubeMusicConnected,
    bool spotifyExpired = false,
    bool youtubeMusicExpired = false,
    bool navidromeConnected = false,
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
      SourceDescriptor(
        kind: SourceKind.spotify,
        name: 'Spotify',
        description: 'Kitaplık, listeler, beğeniler ve öneriler',
        status: _accountStatus(spotifyConnected, spotifyExpired),
        requiresAccount: true,
        capabilities: const {
          SourceCapability.search,
          SourceCapability.library,
          SourceCapability.playlists,
          SourceCapability.likes,
          SourceCapability.recommendations,
          SourceCapability.lyrics,
        },
      ),
      SourceDescriptor(
        kind: SourceKind.youtubeMusic,
        name: 'YouTube Music',
        description: 'Hesap kitaplığı, oynatma ve kişisel öneriler',
        status: _accountStatus(youtubeMusicConnected, youtubeMusicExpired),
        requiresAccount: true,
        capabilities: const {
          SourceCapability.search,
          SourceCapability.playback,
          SourceCapability.library,
          SourceCapability.playlists,
          SourceCapability.likes,
          SourceCapability.recommendations,
          SourceCapability.lyrics,
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
      const SourceDescriptor(
        kind: SourceKind.lastFm,
        name: 'Last.fm',
        description: 'Dinleme geçmişi, keşif ve scrobble',
        status: SourceStatus.available,
        requiresAccount: true,
        capabilities: {
          SourceCapability.search,
          SourceCapability.recommendations,
          SourceCapability.scrobble,
        },
      ),
    ];
  }

  static SourceStatus _accountStatus(bool connected, bool expired) {
    if (expired) return SourceStatus.expired;
    return connected ? SourceStatus.connected : SourceStatus.unavailable;
  }
}
