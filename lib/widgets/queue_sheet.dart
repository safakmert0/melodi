import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/extensions/duration_ext.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import 'image_with_fallback.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final queue = player.queue;
        final currentIndex = player.currentIndex;
        final currentSong = player.currentSong;

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Queue',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            player.isShuffled
                                ? Icons.shuffle_on_rounded
                                : Icons.shuffle_rounded,
                            color: player.isShuffled
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded,
                              color: AppTheme.textSecondary),
                          onPressed: player.clearQueue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.darkDivider),
              Expanded(
                child: queue.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.queue_music_rounded,
                                size: 64, color: AppTheme.textTertiary),
                            SizedBox(height: 16),
                            Text(
                              'Queue is empty',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add songs to start playing',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) newIndex--;
                          player.removeFromQueue(oldIndex);
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
                              color: AppTheme.errorColor,
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => player.removeFromQueue(index),
                            child: ListTile(
                              leading: ArtworkImage(
                                imageBytes: song.albumArt,
                                size: 40,
                                borderRadius: 4,
                              ),
                              title: Text(
                                song.title,
                                style: TextStyle(
                                  color: isCurrent
                                      ? AppTheme.primaryColor
                                      : AppTheme.textPrimary,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.darkDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add to Playlist',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (playlists.isEmpty)
            const Text(
              'No playlists yet. Create one first.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ...playlists.map((pl) => ListTile(
                  title: Text(pl.name,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  leading: const Icon(Icons.playlist_play_rounded,
                      color: AppTheme.textSecondary),
                  onTap: () {
                    context
                        .read<PlaylistProvider>()
                        .addSongToPlaylist(pl.id, song);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to ${pl.name}'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                )),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.add_circle_outline,
                color: AppTheme.primaryColor),
            title: const Text('Create New Playlist',
                style: TextStyle(color: AppTheme.primaryColor)),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('New Playlist',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final pl = await context
                    .read<PlaylistProvider>()
                    .createPlaylist(controller.text.trim());
                context
                    .read<PlaylistProvider>()
                    .addSongToPlaylist(pl.id, song);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Created and added to ${pl.name}'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              }
            },
            child: const Text('Create',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
