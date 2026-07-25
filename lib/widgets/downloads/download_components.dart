import 'package:flutter/material.dart';

import '../../core/melodi_design.dart';
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: MelodiPanel(
        emphasized: activeCount > 0,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    activeCount > 0
                        ? Icons.downloading_rounded
                        : Icons.offline_pin_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeCount > 0
                            ? '$activeCount indirme çalışıyor'
                            : 'Çevrimdışı arşiv hazır',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text('$completedCount tamamlandı • $failedCount sorunlu',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    icon: Icons.sd_storage_rounded,
                    label: 'Kullanım',
                    value: storageLabel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryItem(
                    icon: Icons.high_quality_rounded,
                    label: 'Kalite tercihi',
                    value: qualityLabel,
                    onTap: onQuality,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.folder_rounded,
                    size: 15, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(pathLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text('Akıllı kaynak yedeği',
                    style: TextStyle(
                        color: colors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 10)),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadFilterBar extends StatelessWidget {
  const DownloadFilterBar({
    super.key,
    required this.value,
    required this.countFor,
    required this.onChanged,
  });

  final DownloadViewFilter value;
  final int Function(DownloadViewFilter filter) countFor;
  final ValueChanged<DownloadViewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: DownloadViewFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = DownloadViewFilter.values[index];
          return FilterChip(
            selected: filter == value,
            showCheckmark: false,
            avatar: Icon(filter.icon, size: 16),
            label: Text('${filter.label} ${countFor(filter)}'),
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
    final colors = Theme.of(context).colorScheme;
    final active = task.state == DownloadState.pending ||
        task.state == DownloadState.downloading;
    final failed = task.state == DownloadState.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.14)
            : colors.surfaceContainer.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _TaskArtwork(task: task, selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(task.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(stateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: failed
                                        ? colors.error
                                        : active
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(_qualityLabel(task.requestedQuality),
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (active) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: task.state == DownloadState.pending
                              ? null
                              : task.progress.clamp(0, 1),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (selectionMode)
                  Checkbox(value: selected, onChanged: (_) => onTap())
                else if (active)
                  IconButton(
                    tooltip: 'İptal et',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                  )
                else if (failed)
                  IconButton(
                    tooltip: 'Yeniden dene',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  )
                else
                  IconButton(
                    tooltip: 'Geçmişten kaldır',
                    onPressed: onClearHistory,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
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
    final colors = Theme.of(context).colorScheme;
    final failed = task.state == DownloadState.failed;
    final complete = task.state == DownloadState.completed;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: task.imageUrl == null || task.imageUrl!.isEmpty
              ? Container(
                  width: 54,
                  height: 54,
                  color: colors.surfaceContainerHighest,
                  child: Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : complete
                            ? Icons.music_note_rounded
                            : Icons.download_rounded,
                    color: failed ? colors.error : colors.primary,
                  ),
                )
              : Image.network(
                  task.imageUrl!,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 54,
                    height: 54,
                    color: colors.surfaceContainerHighest,
                    child: Icon(Icons.music_note_rounded,
                        color: colors.onSurfaceVariant),
                  ),
                ),
        ),
        if (complete || selected)
          Positioned(
            right: -1,
            bottom: -1,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: selected ? colors.primary : colors.tertiary,
              child: Icon(selected ? Icons.check_rounded : Icons.offline_pin,
                  size: 12, color: colors.onPrimary),
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
    final colors = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filter.icon,
                  size: 56, color: colors.primary.withValues(alpha: 0.72)),
              const SizedBox(height: 16),
              Text(
                filter == DownloadViewFilter.all
                    ? 'Henüz çevrimdışı müzik yok'
                    : '${filter.label} indirme yok',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                'Arama sonuçlarından, oynatıcıdan veya bir çalma listesinden birden çok parça ekleyebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
