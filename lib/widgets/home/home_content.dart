export 'home_states.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/melodi_design.dart';
import '../../models/song_model.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../screens/downloads_screen.dart';
import '../../screens/library_health_screen.dart';
import '../../screens/listening_history_screen.dart';
import '../../screens/mixes_screen.dart';
import '../image_with_fallback.dart';
import 'home_hero.dart';
import 'home_rails.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.library,
    required this.playlists,
  });

  final LibraryProvider library;
  final PlaylistProvider playlists;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        HomeContinueListening(library: library),
        _QuickActions(
          library: library,
          playlistCount: playlists.playlists.length,
        ),
        _QuickPicks(library: library),
        HomeAlbumRail(library: library),
        if (playlists.playlists.isNotEmpty)
          HomePlaylistRail(playlists: playlists),
        _RecentlyAdded(library: library),
        const SizedBox(height: 176),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.library, required this.playlistCount});

  final LibraryProvider library;
  final int playlistCount;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = library.songs
        .fold<Duration>(Duration.zero, (sum, song) => sum + song.duration)
        .inMinutes;
    final actions = [
      _ActionData(
        icon: Icons.favorite_rounded,
        color: const Color(0xFFFF4D78),
        value: '${library.favorites.length}',
        label: 'Favori',
        onTap: () => _open(context, const ListeningHistoryScreen()),
      ),
      _ActionData(
        icon: Icons.download_done_rounded,
        color: const Color(0xFF32D583),
        value: '${library.songs.length}',
        label: 'Aygıtta',
        onTap: () => _open(context, const DownloadsScreen()),
      ),
      _ActionData(
        icon: Icons.queue_music_rounded,
        color: const Color(0xFF7C9DFF),
        value: '$playlistCount',
        label: 'Liste',
        onTap: () => _open(context, const MixesScreen()),
      ),
      _ActionData(
        icon: Icons.schedule_rounded,
        color: const Color(0xFFFFB547),
        value: totalMinutes >= 60
            ? '${totalMinutes ~/ 60} sa'
            : '$totalMinutes dk',
        label: 'Müzik',
        onTap: () => _open(context, const LibraryHealthScreen()),
      ),
    ];

    return SizedBox(
      height: 102,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, index) => _ActionCard(data: actions[index]),
      ),
    );
  }

  static void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.data});
  final _ActionData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: MelodiPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: data.onTap,
        child: Row(
          children: [
            Icon(data.icon, color: data.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.library});
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final songs = (library.recent.isNotEmpty
            ? library.recent
            : library.mostPlayed.isNotEmpty
                ? library.mostPlayed
                : library.songs)
        .take(6)
        .toList();
    return HomeSection(
      title: 'Senin için',
      subtitle: 'Dinleme alışkanlıklarından hızlı seçimler',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 2.75,
        ),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.read<PlayerProvider>().playFromQueue(songs, index),
              child: Row(
                children: [
                  ArtworkImage(
                    imageBytes: song.albumArt,
                    title: song.title,
                    size: 62,
                    borderRadius: 0,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentlyAdded extends StatelessWidget {
  const _RecentlyAdded({required this.library});
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final songs = List<SongModel>.from(library.songs)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    final items = songs.take(6).toList();
    return HomeSection(
      title: 'Yeni eklenenler',
      subtitle: 'Kitaplığına en son katılan parçalar',
      child: Column(
        children: List.generate(items.length, (index) {
          final song = items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 5,
            leading: ArtworkImage(
              imageBytes: song.albumArt,
              title: song.title,
              size: 52,
              borderRadius: 13,
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${song.artist} · ${song.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Oynat',
              onPressed: () =>
                  context.read<PlayerProvider>().playFromQueue(items, index),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            onTap: () =>
                context.read<PlayerProvider>().playFromQueue(items, index),
          );
        }),
      ),
    );
  }
}
