import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import 'image_with_fallback.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer2<PlayerProvider, LocaleNotifier>(
      builder: (context, player, locale, _) {
        final queue = player.queue;
        final currentIndex = player.currentIndex;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocale.tr('queue'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            player.isShuffled ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                            size: 20,
                            color: player.isShuffled ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_sweep_rounded, size: 20, color: scheme.onSurfaceVariant),
                          onPressed: player.clearQueue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.5), height: 1),
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.queue_music_rounded, size: 48, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              AppLocale.tr('queue_is_empty'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocale.tr('add_songs_to_start'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          player.moveInQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          final isCurrent = index == currentIndex;
                          return Dismissible(
                            key: ValueKey('queue_${song.id}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: scheme.error,
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) => player.removeFromQueue(index),
                            child: ListTile(
                              leading: ArtworkImage(
                                imageBytes: song.albumArt,
                                size: 40,
                                borderRadius: 6,
                              ),
                              title: Text(
                                song.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 13,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => player.playFromQueue(queue, index),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AddToPlaylistSheet extends StatelessWidget {
  final SongModel song;
  final List<PlaylistModel> playlists;

  const AddToPlaylistSheet({
    super.key,
    required this.song,
    required this.playlists,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            AppLocale.tr('add_to_playlist'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (playlists.isEmpty)
            Text(AppLocale.tr('no_playlists_yet'), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))
          else
            ...playlists.map((pl) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(pl.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface)),
                  leading: Icon(Icons.playlist_play_rounded, color: scheme.onSurfaceVariant, size: 20),
                  onTap: () {
                    context.read<PlaylistProvider>().addSongToPlaylist(pl.id, song);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${AppLocale.tr('added_to')} ${pl.name}')),
                    );
                  },
                )),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_circle_outline, color: scheme.onSurfaceVariant, size: 20),
            title: Text(AppLocale.tr('create_new_playlist'), style: TextStyle(color: scheme.onSurface, fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _showCreatePlaylistDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        title: Text(AppLocale.tr('new_playlist'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: AppLocale.tr('playlist_name'),
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.tr('cancel'), style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final playlistProvider = context.read<PlaylistProvider>();
                final messenger = ScaffoldMessenger.of(context);
                final pl = await playlistProvider.createPlaylist(controller.text.trim());
                await playlistProvider.addSongToPlaylist(pl.id, song);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(content: Text('${AppLocale.tr('created_and_added_to')} ${pl.name}')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppLocale.tr('create')),
          ),
        ],
      ),
    );
  }
}
