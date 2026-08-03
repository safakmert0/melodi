import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/melodi_design.dart';
import '../../models/song_model.dart';
import '../image_with_fallback.dart';

enum LibrarySourceFilter { all, device, spotify, youtube }

extension LibrarySourceFilterUi on LibrarySourceFilter {
  String get label => switch (this) {
        LibrarySourceFilter.all => 'Tümü',
        LibrarySourceFilter.device => 'Aygıtta',
        LibrarySourceFilter.spotify => 'Spotify',
        LibrarySourceFilter.youtube => 'YouTube',
      };

  IconData get icon => switch (this) {
        LibrarySourceFilter.all => Icons.all_inclusive_rounded,
        LibrarySourceFilter.device => Icons.smartphone_rounded,
        LibrarySourceFilter.spotify => Icons.graphic_eq_rounded,
        LibrarySourceFilter.youtube => Icons.play_circle_fill_rounded,
      };

  bool matches(SongModel song) {
    final path = song.filePath.toLowerCase();
    return switch (this) {
      LibrarySourceFilter.all => true,
      LibrarySourceFilter.device => !path.startsWith('spotify://') &&
          !path.startsWith('youtube://') &&
          !path.startsWith('http://') &&
          !path.startsWith('https://'),
      LibrarySourceFilter.spotify => path.startsWith('spotify://'),
      LibrarySourceFilter.youtube => path.startsWith('youtube://') ||
          path.startsWith('http://') ||
          path.startsWith('https://'),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Profili aç',
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: colors.surfaceContainerHighest,
                child: Icon(Icons.person_rounded,
                    size: 21, color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KİTAPLIĞIN',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    )),
                Text('Müziğin, tek yerde',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 21,
                        )),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kaynaklar',
            onPressed: onSources,
            icon: const Icon(Icons.hub_rounded),
          ),
          IconButton(
            tooltip: 'Kitaplıkta ara',
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton.filled(
            tooltip: 'Ekle veya içe aktar',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: MelodiPanel(
        emphasized: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
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
                Icon(Icons.library_music_rounded,
                    size: 40, color: colors.primary.withValues(alpha: 0.8)),
              ],
            ),
            if (isScanning) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Müzik kitaplığı taranıyor…',
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12)),
                  ),
                  Text('${(scanProgress * 100).round()}%',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: scanProgress <= 0 ? null : scanProgress),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Tümünü çal'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Karıştır',
                  onPressed: onShuffle,
                  icon: const Icon(Icons.shuffle_rounded),
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
        Text(value,
            style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        Text(label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
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
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: LibrarySourceFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = LibrarySourceFilter.values[index];
                return FilterChip(
                  selected: item == source,
                  showCheckmark: false,
                  avatar: Icon(item.icon, size: 16),
                  label: Text(item.label),
                  onSelected: (_) => onSourceChanged(item),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: LibraryContentFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = LibraryContentFilter.values[index];
                return ChoiceChip(
                  selected: item == content,
                  showCheckmark: false,
                  avatar: Icon(item.icon, size: 16),
                  label: Text(item.label),
                  onSelected: (_) => onContentChanged(item),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 10, 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onSort,
                  icon: Icon(
                    ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 16,
                  ),
                  label: Text(sortLabel),
                ),
                const Spacer(),
                Text(content.label,
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                IconButton(
                  tooltip: isGrid ? 'Liste görünümü' : 'Izgara görünümü',
                  onPressed: onToggleGrid,
                  icon: Icon(isGrid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: _Artwork(
        bytes: song.albumArt,
        icon: Icons.music_note_rounded,
        size: 54,
      ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Row(
        children: [
          _SourceDot(song: song),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${song.artist} • ${song.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Diğer',
        onPressed: onMore,
        icon: const Icon(Icons.more_horiz_rounded),
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
    final path = song.filePath.toLowerCase();
    final color = path.startsWith('spotify://')
        ? const Color(0xFF1ED760)
        : path.startsWith('youtube://') || path.startsWith('http')
            ? const Color(0xFFFF4D4D)
            : Theme.of(context).colorScheme.primary;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? artwork;
  final Gradient? gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading:
          _Artwork(bytes: artwork, icon: icon, gradient: gradient, size: 58),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
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
    this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? artwork;
  final Gradient? gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MelodiRadius.artwork),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Artwork(
                bytes: artwork,
                icon: icon,
                gradient: gradient,
                size: double.infinity,
                radius: MelodiRadius.artwork,
              ),
            ),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.bytes,
    required this.icon,
    required this.size,
    this.gradient,
    this.radius = 12,
  });

  final Uint8List? bytes;
  final IconData icon;
  final double size;
  final Gradient? gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = gradient == null && icon == Icons.music_note_rounded
        ? MelodiArtworkFallback(
            size: size.isFinite ? size : null,
            borderRadius: radius,
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? colors.surfaceContainerHighest : null,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(
              icon,
              size: size.isFinite ? size * 0.38 : 40,
              color: gradient == null ? colors.onSurfaceVariant : Colors.white,
            ),
          );
    if (bytes == null || bytes!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.memory(
        bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_add_rounded,
                  size: 56, color: colors.primary.withValues(alpha: 0.75)),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 20,
                      )),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Müzik ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
