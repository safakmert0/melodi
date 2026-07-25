enum SourceKind {
  local,
  spotify,
  youtubeMusic,
  youtube,
  deezer,
  jioSaavn,
  lastFm,
}

enum SourceCapability {
  search,
  playback,
  library,
  playlists,
  likes,
  recommendations,
  lyrics,
  scrobble,
  downloads,
  lossless,
}

enum SourceStatus { available, connected, expired, unavailable }

class SourceDescriptor {
  const SourceDescriptor({
    required this.kind,
    required this.name,
    required this.description,
    required this.status,
    required this.capabilities,
    this.requiresAccount = false,
  });

  final SourceKind kind;
  final String name;
  final String description;
  final SourceStatus status;
  final Set<SourceCapability> capabilities;
  final bool requiresAccount;

  bool supports(SourceCapability capability) =>
      capabilities.contains(capability);

  bool get isReady =>
      status == SourceStatus.available || status == SourceStatus.connected;
}
