import 'package:flutter/material.dart';
import '../../services/download_manager.dart';

enum DownloadViewFilter { all, active, completed, failed }

extension DownloadViewFilterUi on DownloadViewFilter {
  String get label => switch (this) {
        DownloadViewFilter.all => 'Tümü',
        DownloadViewFilter.active => 'Devam eden',
        DownloadViewFilter.completed => 'Tamamlanan',
        DownloadViewFilter.failed => 'Sorunlu',
      };
  IconData get icon => switch (this) {
        DownloadViewFilter.all => Icons.all_inclusive_rounded,
        DownloadViewFilter.active => Icons.downloading_rounded,
        DownloadViewFilter.completed => Icons.download_done_rounded,
        DownloadViewFilter.failed => Icons.error_outline_rounded,
      };
}

class DownloadSummary extends StatelessWidget {
  const DownloadSummary({
    super.key,
    required this.activeCount,
    required this.completedCount,
    required this.failedCount,
    required this.storageLabel,
    required this.qualityLabel,
    required this.pathLabel,
    required this.onQuality,
  });

  final int activeCount;
  final int completedCount;
  final int failedCount;
  final String storageLabel;
  final String qualityLabel;
  final String pathLabel;
  final VoidCallback onQuality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Icon(activeCount > 0 ? Icons.downloading_rounded : Icons.offline_pin_rounded, size: 20, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activeCount > 0 ? '$activeCount indirme çalışıyor' : 'Çevrimdışı arşiv hazır', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('$completedCount tamamlandı • $failedCount sorunlu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _SummaryItem(icon: Icons.sd_storage_rounded, label: 'Kullanım', value: storageLabel)),
                const SizedBox(width: 8),
                Expanded(child: _SummaryItem(icon: Icons.high_quality_rounded, label: 'Kalite tercihi', value: qualityLabel, onTap: onQuality)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.folder_rounded, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(pathLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11))),
                const SizedBox(width: 8),
                Text('Akıllı kaynak yedeği', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4))),
          child: Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10)),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadFilterBar extends StatelessWidget {
  const DownloadFilterBar({super.key, required this.value, required this.countFor, required this.onChanged});
  final DownloadViewFilter value;
  final int Function(DownloadViewFilter filter) countFor;
  final ValueChanged<DownloadViewFilter> onChanged;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: DownloadViewFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = DownloadViewFilter.values[index];
          final selected = filter == value;
          return FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(filter.icon, size: 14, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
            label: Text('${filter.label} ${countFor(filter)}', style: TextStyle(fontSize: 12, color: selected ? scheme.onSurface : scheme.onSurfaceVariant)),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: selected ? 0.7 : 0.5)),
            selectedColor: scheme.surfaceContainerHigh,
            backgroundColor: scheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (_) => onChanged(filter),
          );
        },
      ),
    );
  }
}

class DownloadTaskCard extends StatelessWidget {
  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.stateLabel,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onCancel,
    required this.onRetry,
    required this.onClearHistory,
  });
  final DownloadTask task;
  final String stateLabel;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onClearHistory;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = task.state == DownloadState.pending || task.state == DownloadState.downloading;
    final failed = task.state == DownloadState.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: selected ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: scheme.outlineVariant.withValues(alpha: selected ? 0.7 : 0.5))),
            child: Row(
              children: [
                _TaskArtwork(task: task, selected: selected),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(task.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Text(stateLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: failed ? scheme.error : active ? scheme.onSurfaceVariant : scheme.onSurfaceVariant, fontSize: 10))),
                      Text(_qualityLabel(task.requestedQuality), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9)),
                    ]),
                    if (active) ...[const SizedBox(height: 6), LinearProgressIndicator(value: task.state == DownloadState.pending ? null : task.progress.clamp(0, 1), minHeight: 2, backgroundColor: scheme.surfaceContainerHighest, color: scheme.onSurfaceVariant, borderRadius: BorderRadius.circular(2))],
                  ]),
                ),
                const SizedBox(width: 6),
                if (selectionMode) Checkbox(value: selected, onChanged: (_) => onTap())
                else if (active) IconButton(tooltip: 'İptal et', onPressed: onCancel, icon: const Icon(Icons.close_rounded, size: 18))
                else if (failed) IconButton(tooltip: 'Yeniden dene', onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18))
                else IconButton(tooltip: 'Geçmişten kaldır', onPressed: onClearHistory, icon: const Icon(Icons.more_horiz_rounded, size: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _qualityLabel(String quality) => switch (quality) {
        'normal' => 'NORMAL',
        'lossless' => 'KAYIPSIZ TERCİH',
        _ => 'YÜKSEK',
      };
}

class _TaskArtwork extends StatelessWidget {
  const _TaskArtwork({required this.task, required this.selected});
  final DownloadTask task;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = task.state == DownloadState.failed;
    final complete = task.state == DownloadState.completed;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: task.imageUrl == null || task.imageUrl!.isEmpty
              ? Container(width: 48, height: 48, color: scheme.surfaceContainerHighest, child: Icon(failed ? Icons.error_outline_rounded : complete ? Icons.music_note_rounded : Icons.download_rounded, size: 20, color: scheme.onSurfaceVariant))
              : Image.network(task.imageUrl!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: scheme.surfaceContainerHighest, child: Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant, size: 20))),
        ),
        if (complete || selected)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.onSurface, border: Border.all(color: scheme.surface, width: 1.5)),
              child: Icon(selected ? Icons.check_rounded : Icons.offline_pin, size: 9, color: scheme.surface),
            ),
          ),
      ],
    );
  }
}

class DownloadEmptyState extends StatelessWidget {
  const DownloadEmptyState({super.key, required this.filter});
  final DownloadViewFilter filter;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
                child: Icon(filter.icon, size: 24, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Text(filter == DownloadViewFilter.all ? 'Henüz çevrimdışı müzik yok' : '${filter.label} indirme yok', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Arama sonuçlarından, oynatıcıdan veya bir çalma listesinden birden çok parça ekleyebilirsin.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
