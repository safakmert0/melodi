import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/melodi_design.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../screens/mixes_screen.dart';
import '../../screens/playlist_detail_screen.dart';
import '../image_with_fallback.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.45,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class HomeAlbumRail extends StatelessWidget {
  const HomeAlbumRail({super.key, required this.library});
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final albums = library.albums.take(12).toList();
    return HomeSection(
      title: 'Albüm rafın',
      subtitle: '${library.albums.length} albüm · kapaklara göre göz at',
      child: SizedBox(
        height: 218,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: albums.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final album = albums[index];
            final songs = library.songs
                .where((song) => album.songIds.contains(song.id))
                .toList();
            return SizedBox(
              width: 154,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: songs.isEmpty
                    ? null
                    : () =>
                        context.read<PlayerProvider>().playFromQueue(songs, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtworkImage(
                      imageBytes: album.artwork,
                      title: album.name,
                      size: 154,
                      borderRadius: 16,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomePlaylistRail extends StatelessWidget {
  const HomePlaylistRail({
    super.key,
    required this.playlists,
    required this.library,
  });
  final PlaylistProvider playlists;
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final items = playlists.playlists.take(10).toList();
    return HomeSection(
      title: 'Listelerin',
      subtitle: 'Yerel ve eşzamanlanan koleksiyonların',
      actionLabel: 'Miksler',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MixesScreen()),
      ),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final playlist = items[index];
            final coverSongs = library.songs
                .where((song) =>
                    playlist.songIds.contains(song.id) &&
                    song.albumArt != null &&
                    song.albumArt!.isNotEmpty)
                .toList();
            final artwork = coverSongs.isEmpty
                ? playlist.artwork
                : coverSongs.first.albumArt;
            return SizedBox(
              width: 210,
              child: MelodiPanel(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailScreen(playlist: playlist),
                  ),
                ),
                child: Row(
                  children: [
                    ArtworkImage(
                      imageBytes: artwork,
                      title: playlist.name,
                      size: 52,
                      borderRadius: 14,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${playlist.songCount} şarkı',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
