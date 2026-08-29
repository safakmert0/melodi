import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/song_model.dart';

enum LibrarySourceFilter { all, device, spotify, youtube, downloads }

extension LibrarySourceFilterUi on LibrarySourceFilter {
  String get label => switch (this) {
        LibrarySourceFilter.all => 'Tümü',
        LibrarySourceFilter.device => 'Aygıtta',
        LibrarySourceFilter.spotify => 'Spotify',
        LibrarySourceFilter.youtube => 'YouTube',
        LibrarySourceFilter.downloads => 'İndirilenler',
      };

  IconData get icon => switch (this) {
        LibrarySourceFilter.all => Icons.all_inclusive_rounded,
        LibrarySourceFilter.device => Icons.smartphone_rounded,
        LibrarySourceFilter.spotify => Icons.graphic_eq_rounded,
        LibrarySourceFilter.youtube => Icons.play_circle_fill_rounded,
        LibrarySourceFilter.downloads => Icons.download_rounded,
      };

  bool matches(SongModel song) {
    final path = song.filePath.toLowerCase();
    return switch (this) {
      LibrarySourceFilter.all => true,
      LibrarySourceFilter.device =>
        !path.startsWith('spotify://') &&
            !path.startsWith('youtube://') &&
            !path.startsWith('http://') &&
            !path.startsWith('https://'),
      LibrarySourceFilter.spotify => path.startsWith('spotify://'),
      LibrarySourceFilter.youtube =>
        path.startsWith('youtube://') ||
            path.startsWith('http://') ||
            path.startsWith('https://'),
      LibrarySourceFilter.downloads => false,
    };
  }
}

enum LibraryContentFilter { songs, albums, artists, playlists }

extension LibraryContentFilterUi on LibraryContentFilter {
  String get label => switch (this) {
        LibraryContentFilter.songs => 'Parçalar',
        LibraryContentFilter.albums => 'Albümler',
        LibraryContentFilter.artists => 'Sanatçılar',
        LibraryContentFilter.playlists => 'Listeler',
      };

  IconData get icon => switch (this) {
        LibraryContentFilter.songs => Icons.music_note_rounded,
        LibraryContentFilter.albums => Icons.album_rounded,
        LibraryContentFilter.artists => Icons.person_rounded,
        LibraryContentFilter.playlists => Icons.queue_music_rounded,
      };
}

class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.onProfile,
    required this.onSearch,
    required this.onSources,
    required this.onAdd,
  });

  final VoidCallback onProfile;
  final VoidCallback onSearch;
  final VoidCallback onSources;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitaplığın',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Müziğin, tek yerde',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kaynaklar',
            onPressed: onSources,
            icon: Icon(Icons.hub_rounded,
                size: 20, color: colors.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Kitaplıkta ara',
            onPressed: onSearch,
            icon: Icon(Icons.search_rounded,
                size: 20, color: colors.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Ekle veya içe aktar',
            onPressed: onAdd,
            style: IconButton.styleFrom(
              backgroundColor: colors.onSurface,
              foregroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(36, 36),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class LibraryOverview extends StatelessWidget {
  const LibraryOverview({
    super.key,
    required this.songCount,
    required this.albumCount,
    required this.playlistCount,
    required this.totalMinutes,
    required this.isScanning,
    required this.scanProgress,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final int songCount;
  final int albumCount;
  final int playlistCount;
  final int totalMinutes;
  final bool isScanning;
  final double scanProgress;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Metric(value: '$songCount', label: 'parça'),
                      _Metric(value: '$albumCount', label: 'albüm'),
                      _Metric(value: '$playlistCount', label: 'liste'),
                      _Metric(
                        value: totalMinutes >= 60
                            ? '${(totalMinutes / 60).toStringAsFixed(1)} sa'
                            : '$totalMinutes dk',
                        label: 'toplam',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.library_music_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (isScanning) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Müzik kitaplığı taranıyor…',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${(scanProgress * 100).round()}%',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: scanProgress <= 0 ? null : scanProgress,
                backgroundColor: colors.surfaceContainerHighest,
                color: colors.onSurfaceVariant,
                minHeight: 3,
                borderRadius: BorderRadius.circular(10),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Tümünü çal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.onSurface,
                      foregroundColor: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onShuffle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(12),
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Icon(Icons.shuffle_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}

class LibraryFilters extends StatelessWidget {
  const LibraryFilters({
    super.key,
    required this.source,
    required this.content,
    required this.isGrid,
    required this.sortLabel,
    required this.ascending,
    required this.onSourceChanged,
    required this.onContentChanged,
    required this.onToggleGrid,
    required this.onSort,
  });

  final LibrarySourceFilter source;
  final LibraryContentFilter content;
  final bool isGrid;
  final String sortLabel;
  final bool ascending;
  final ValueChanged<LibrarySourceFilter> onSourceChanged;
  final ValueChanged<LibraryContentFilter> onContentChanged;
  final VoidCallback onToggleGrid;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: LibrarySourceFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = LibrarySourceFilter.values[index];
                final selected = item == source;
                return FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(item.icon,
                      size: 14,
                      color: selected
                          ? colors.onSurface
                          : colors.onSurfaceVariant),
                  label: Text(item.label),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        selected ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                  backgroundColor: colors.surfaceContainer,
                  selectedColor: colors.surfaceContainerHigh,
                  side: BorderSide(
                    color: selected
                        ? colors.outlineVariant.withValues(alpha: 0.7)
                        : colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  onSelected: (_) => onSourceChanged(item),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: LibraryContentFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = LibraryContentFilter.values[index];
                final selected = item == content;
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(item.icon,
                      size: 14,
                      color: selected
                          ? colors.onSurface
                          : colors.onSurfaceVariant),
                  label: Text(item.label),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        selected ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                  backgroundColor: colors.surfaceContainer,
                  selectedColor: colors.surfaceContainerHigh,
                  side: BorderSide(
                    color: selected
                        ? colors.outlineVariant.withValues(alpha: 0.7)
                        : colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  onSelected: (_) => onContentChanged(item),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onSort,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 14,
                  ),
                  label: Text(
                    sortLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  content.label,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: isGrid ? 'Liste görünümü' : 'Izgara görünümü',
                  onPressed: onToggleGrid,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isGrid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LibrarySongTile extends StatelessWidget {
  const LibrarySongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMore,
  });

  final SongModel song;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _Artwork(
        bytes: song.albumArt,
        icon: Icons.music_note_rounded,
        size: 48,
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: colors.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          _SourceDot(song: song),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${song.artist} • ${song.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ),
        ],
      ),
      trailing: onMore == null
          ? null
          : IconButton(
              tooltip: 'Diğer',
              onPressed: onMore,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_horiz_rounded,
                  size: 18, color: colors.onSurfaceVariant),
            ),
      onTap: onTap,
    );
  }
}

class _SourceDot extends StatelessWidget {
  const _SourceDot({required this.song});

  final SongModel song;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Neutral dot regardless of source — no neon.
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: colors.outlineVariant.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
    );
  }
}

class LibraryCollectionTile extends StatelessWidget {
  const LibraryCollectionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.artwork,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? artwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _Artwork(bytes: artwork, icon: icon, size: 48),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 18, color: colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class LibraryCollectionCard extends StatelessWidget {
  const LibraryCollectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.artwork,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? artwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Artwork(
              bytes: artwork,
              icon: icon,
              size: double.infinity,
              radius: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.bytes,
    required this.icon,
    required this.size,
    this.radius = 10,
  });

  final Uint8List? bytes;
  final IconData icon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Icon(
        icon,
        size: size.isFinite ? size * 0.36 : 28,
        color: colors.onSurfaceVariant,
      ),
    );
    if (bytes == null || bytes!.isEmpty) return fallback;
    // For music notes keep subtle icon fallback when needed, otherwise image.
    if (bytes == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Image.memory(
            bytes!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      ),
    );
  }
}

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.onAdd,
  });

  final String title;
  final String message;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.library_add_rounded,
                  size: 24,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Müzik ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
