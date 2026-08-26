import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/melodi_design.dart';
import '../theme/app_tokens.dart';
import '../models/extension.dart';
import '../services/extension_service.dart';

/// SpotiFLAC tarzı uygulama içi eklenti mağazası.
///
/// Depo (registry) bağlantısı eklenir; depodaki eklentiler tek dokunuşla
/// kurulur, güncellenir veya kaldırılır. Sunucu adresi girmek gerekmez:
/// adresler eklenti manifestlerinin içinde taşınır.
class ExtensionStoreScreen extends StatefulWidget {
  const ExtensionStoreScreen({super.key});

  @override
  State<ExtensionStoreScreen> createState() => _ExtensionStoreScreenState();
}

class _ExtensionStoreScreenState extends State<ExtensionStoreScreen> {
  bool _loadingRegistries = false;
  List<RepoSnapshot> _snapshots = const [];
  final Set<String> _busyIds = {};

  ExtensionService get _service => ExtensionService.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loadingRegistries = true);
    try {
      final snapshots = await _service.fetchRegistries();
      if (mounted) setState(() => _snapshots = snapshots);
    } finally {
      if (mounted) setState(() => _loadingRegistries = false);
    }
  }

  Future<void> _addRepoDialog() async {
    final controller = TextEditingController(
        text: _service.repos.contains(ExtensionService.officialRepoUrl)
            ? ''
            : ExtensionService.officialRepoUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Depo ekle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://…/registry.json',
            labelText: 'Depo bağlantısı',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    try {
      await _service.addRepo(url);
      await _refresh();
    } on FormatException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _install(RegistryEntry entry) async {
    setState(() => _busyIds.add(entry.id));
    try {
      await _service.installFromEntry(entry);
      if (mounted) _toast('${entry.name} kuruldu');
    } catch (e) {
      if (mounted) _toast('Kurulum başarısız: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(entry.id));
    }
  }

  Future<void> _uninstallConfirm(InstalledExtension installed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${installed.manifest.name} kaldırılsın mı?'),
        content: const Text(
            'Eklentinin sağladığı sunucu bağlantısı devre dışı kalır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.uninstall(installed.manifest.id);
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error
          ? MelodiTheme.errorRed
          : Theme.of(context).colorScheme.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eklenti Mağazası'),
        actions: [
          IconButton(
            tooltip: 'Depoları yenile',
            onPressed: _loadingRegistries ? null : _refresh,
            icon: _loadingRegistries
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _sectionHeader(
              'Kurulu eklentiler',
              '${_service.installed.where((e) => e.enabled).length} etkin',
            ),
            if (_service.installed.isEmpty)
              const _EmptyHint(
                icon: Icons.extension_rounded,
                message:
                    'Henüz eklenti kurulu değil. Aşağıdaki depolardan bir '
                    'sağlayıcı kur; sunucu adreslerini eklentiler taşır.',
              )
            else
              for (final installed in _service.installed)
                _InstalledCard(
                  installed: installed,
                  canMoveUp: _canMove(installed, up: true),
                  canMoveDown: _canMove(installed, up: false),
                  onToggle: (value) => _service.setEnabled(
                      installed.manifest.id, value),
                  onUp: () => _service.move(installed.manifest.kind,
                      installed.manifest.id,
                      up: true),
                  onDown: () => _service.move(installed.manifest.kind,
                      installed.manifest.id,
                      up: false),
                  onDelete: () => _uninstallConfirm(installed),
                ),
            const SizedBox(height: 24),
            _sectionHeader('Depolar', null),
            MelodiPanel(
              padding: const EdgeInsets.symmetric(
                  horizontal: MelodiSpacing.md, vertical: MelodiSpacing.xs),
              child: Column(
                children: [
                  for (final repo in _service.repos)
                    Row(
                      children: [
                        const Icon(Icons.folder_special_outlined, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _repoLabel(repo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Depoyu kaldır',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () async {
                            await _service.removeRepo(repo);
                            await _refresh();
                          },
                        ),
                      ],
                    ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_link_rounded),
                    title: const Text('Depo ekle'),
                    subtitle: const Text('registry.json bağlantısı'),
                    onTap: _addRepoDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Mağaza', null),
            if (!_loadingRegistries && _snapshots.isEmpty)
              const _EmptyHint(
                icon: Icons.storefront_rounded,
                message: 'Depolar henüz yüklenmedi. Yenile düğmesine bas.',
              ),
            for (final snapshot in _snapshots) ...[
              if (snapshot.hasError)
                _RepoErrorCard(snapshot: snapshot, onRetry: _refresh)
              else ...[
                for (final entry in snapshot.registry?.entries ?? const [])
                  _RegistryEntryCard(
                    entry: entry,
                    busy: _busyIds.contains(entry.id),
                    installed: _service.installedById(entry.id),
                    onInstall: () => _install(entry),
                  ),
                if ((snapshot.registry?.entries.length ?? 0) == 0)
                  _EmptyHint(
                    icon: Icons.inbox_rounded,
                    message: '${snapshot.registry?.name} içinde eklenti yok',
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _repoLabel(String url) {
    if (url == ExtensionService.officialRepoUrl) {
      return 'Resmî Melodi deposu';
    }
    final uri = Uri.tryParse(url);
    return uri?.host ?? url;
  }

  Widget _sectionHeader(String title, String? badge) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                     .withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  bool _canMove(InstalledExtension target, {required bool up}) {
    final sameKind = _service.installed
        .where((e) => e.manifest.kind == target.manifest.kind)
        .toList();
    final index =
        sameKind.indexWhere((e) => e.manifest.id == target.manifest.id);
    if (index < 0) return false;
    if (up) return index > 0;
    return index < sameKind.length - 1;
  }
}

// ---------------------------------------------------------------------------
// Kurulu eklenti kartı
// ---------------------------------------------------------------------------

class _InstalledCard extends StatelessWidget {
  const _InstalledCard({
    required this.installed,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  final InstalledExtension installed;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manifest = installed.manifest;
    final outdated = manifest.minAppVersion != null &&
        _compareVersions(AppConstants.appVersion, manifest.minAppVersion!) < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: installed.enabled ? 1 : 0.55,
        child: MelodiPanel(
          emphasized: installed.enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _KindIcon(kind: manifest.kind),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(manifest.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${manifest.kind.label} · v${manifest.version} · ${manifest.author}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: installed.enabled, onChanged: onToggle),
                ],
              ),
              if (manifest.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(manifest.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 6),
              Text(manifest.baseUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  )),
              if (outdated) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: 4),
                    Text(
                        'Melodi ≥ ${manifest.minAppVersion} gerektirir',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Önceliği yükselt',
                    onPressed: canMoveUp ? onUp : null,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Önceliği düşür',
                    onPressed: canMoveDown ? onDown : null,
                    icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Kaldır',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: theme.colorScheme.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _compareVersions(String a, String b) {
    List<int> parse(String value) =>
        value.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pa = parse(a);
    final pb = parse(b);
    for (var i = 0; i < pa.length.clamp(0, pb.length); i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return pa.length.compareTo(pb.length);
  }
}

// ---------------------------------------------------------------------------
// Depodaki satın alınabilir eklenti kartı
// ---------------------------------------------------------------------------

class _RegistryEntryCard extends StatelessWidget {
  const _RegistryEntryCard({
    required this.entry,
    required this.busy,
    required this.installed,
    required this.onInstall,
  });

  final RegistryEntry entry;
  final bool busy;
  final InstalledExtension? installed;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsUpdate = installed != null &&
        entry.version != null &&
        entry.version != installed!.manifest.version;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MelodiPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _KindIcon(kind: entry.kind ?? ExtensionKind.backend),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (entry.kind != null) entry.kind!.label,
                          if (entry.version != null) 'v${entry.version}',
                          if (entry.author != null) entry.author!,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (installed == null)
                  FilledButton.icon(
                    onPressed: busy ? null : onInstall,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Kur'),
                  )
                else
                  needsUpdate
                      ? OutlinedButton.icon(
                          onPressed: busy ? null : onInstall,
                          icon: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.update_rounded, size: 18),
                          label: const Text('Güncelle'),
                        )
                      : Chip(
                          avatar: Icon(Icons.check_circle_rounded,
                              size: 16, color: theme.colorScheme.primary),
                          label: const Text('Kurulu'),
                        ),
              ],
            ),
            if ((entry.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(entry.description!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepoErrorCard extends StatelessWidget {
  const _RepoErrorCard({required this.snapshot, required this.onRetry});

  final RepoSnapshot snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MelodiPanel(
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Uri.parse(snapshot.url).host,
                      style: theme.textTheme.titleSmall),
                  Text(snapshot.error ?? 'Bilinmeyen hata',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 34, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final ExtensionKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      ExtensionKind.backend => (
          Icons.dns_rounded,
          const Color(0xFF6C8CFF),
        ),
      ExtensionKind.hifi => (
          Icons.graphic_eq_rounded,
          const Color(0xFF32D583),
        ),
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: context.tokens.borderRadiusCover,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
