import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/melodi_design.dart';
import '../models/extension.dart';
import '../models/source_descriptor.dart';
import '../providers/connection_provider.dart';
import '../services/extension_service.dart';
import '../services/source_catalog.dart';
import '../services/navidrome_service.dart';
import 'extension_store_screen.dart';
import 'navidrome_settings_screen.dart';
import 'settings_screen.dart';

class SourceHubScreen extends StatefulWidget {
  const SourceHubScreen({super.key});

  @override
  State<SourceHubScreen> createState() => _SourceHubScreenState();
}

class _SourceHubScreenState extends State<SourceHubScreen> {
  bool _navidromeConnected = false;
  List<InstalledExtension> _extensions = const [];

  @override
  void initState() {
    super.initState();
    _loadNavidromeStatus();
    _loadExtensions();
    ExtensionService.instance.addListener(_onExtensionsChanged);
  }

  @override
  void dispose() {
    ExtensionService.instance.removeListener(_onExtensionsChanged);
    super.dispose();
  }

  void _onExtensionsChanged() {
    if (mounted) setState(() => _extensions = _activeExtensions());
  }

  Future<void> _loadExtensions() async {
    await ExtensionService.instance.ensureLoaded();
    if (mounted) setState(() => _extensions = _activeExtensions());
  }

  List<InstalledExtension> _activeExtensions() =>
      ExtensionService.instance.installed.where((e) => e.enabled).toList();

  Future<void> _loadNavidromeStatus() async {
    final connected = await NavidromeService.instance.isConfigured();
    if (mounted) setState(() => _navidromeConnected = connected);
  }

  Future<void> _refresh(ConnectionProvider connection) async {
    await Future.wait([
      connection.refreshStatus(),
      _loadNavidromeStatus(),
      _loadExtensions(),
    ]);
  }

  Future<void> _openSource(
    BuildContext context,
    SourceDescriptor source,
  ) async {
    Widget? target;
    switch (source.kind) {
      case SourceKind.extension:
        target = const ExtensionStoreScreen();
      case SourceKind.navidrome:
        target = const NavidromeSettingsScreen();
      default:
        if (source.requiresAccount) target = const SettingsScreen();
    }
    if (target == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => target!),
    );
    if (source.kind == SourceKind.navidrome) await _loadNavidromeStatus();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final sources = SourceCatalog.build(
      spotifyConnected: connection.spotifyConnected,
      spotifyExpired: connection.spotifyExpired,
      youtubeMusicConnected: connection.ytMusicConnected,
      youtubeMusicExpired: connection.ytMusicExpired,
      navidromeConnected: _navidromeConnected,
      extensions: _extensions,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müzik kaynakları'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => _refresh(connection),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(connection),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Tek kitaplık, istediğin kaynaklar',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Melodi yalnızca kaynağın desteklediği işlemleri gösterir. '
              'Hesaplarını bağladığında kitaplık ve öneriler burada birleşir.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 22),
            for (final source in sources) ...[
              _SourceCard(
                source: source,
                onTap: () => _openSource(context, source),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            _StoreCta(onTap: () => _openStore(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ExtensionStoreScreen()),
    );
  }
}

class _StoreCta extends StatelessWidget {
  const _StoreCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MelodiPanel(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary .withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.extension_rounded,
                color: theme.colorScheme.primary, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eklenti mağazası',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Topluluk sağlayıcılarını bağlantı ile ekle',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onTap});

  final SourceDescriptor source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MelodiPanel(
      emphasized: source.status == SourceStatus.connected,
      onTap: source.requiresAccount ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SourceIcon(kind: source.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: source.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: source.capabilities
                .map((capability) => _CapabilityChip(capability: capability))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.kind});
  final SourceKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      SourceKind.local => (Icons.phone_iphone_rounded, const Color(0xFF7C9DFF)),
      SourceKind.spotify => (Icons.graphic_eq_rounded, const Color(0xFF1ED760)),
      SourceKind.youtubeMusic => (
          Icons.play_circle_fill_rounded,
          const Color(0xFFFF3D5A)
        ),
      SourceKind.youtube => (
          Icons.smart_display_rounded,
          const Color(0xFFFF453A)
        ),
      SourceKind.deezer => (Icons.equalizer_rounded, const Color(0xFFA970FF)),
      SourceKind.jioSaavn => (Icons.waves_rounded, const Color(0xFF2BC5B4)),
      SourceKind.lastFm => (Icons.insights_rounded, const Color(0xFFD51007)),
      SourceKind.navidrome => (Icons.dns_rounded, const Color(0xFF6C8CFF)),
      SourceKind.extension => (
          Icons.extension_rounded,
          const Color(0xFF32D583)
        ),
    };
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color .withOpacity(0.16),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SourceStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      SourceStatus.connected => ('Bağlı', const Color(0xFF32D583)),
      SourceStatus.available => ('Hazır', colors.primary),
      SourceStatus.expired => ('Yenile', colors.error),
      SourceStatus.unavailable => ('Bağlan', colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color .withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.capability});
  final SourceCapability capability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
             .withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(capability),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  String _label(SourceCapability value) => switch (value) {
        SourceCapability.search => 'Arama',
        SourceCapability.playback => 'Oynatma',
        SourceCapability.library => 'Kitaplık',
        SourceCapability.playlists => 'Listeler',
        SourceCapability.likes => 'Beğeniler',
        SourceCapability.recommendations => 'Öneriler',
        SourceCapability.lyrics => 'Sözler',
        SourceCapability.scrobble => 'Scrobble',
        SourceCapability.downloads => 'Çevrimdışı',
        SourceCapability.lossless => 'Kayıpsız',
      };
}
