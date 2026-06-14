import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/extensions/duration_ext.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
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
  final List<String> playlistNames;

  const AddToPlaylistSheet({
    super.key,
    required this.song,
    required this.playlistNames,
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
          if (playlistNames.isEmpty)
            const Text(
              'No playlists yet. Create one first.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ...playlistNames.map((name) => ListTile(
                  title: Text(name,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  leading: const Icon(Icons.playlist_play_rounded,
                      color: AppTheme.textSecondary),
                  onTap: () => Navigator.pop(context, name),
                )),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.add_circle_outline,
                color: AppTheme.primaryColor),
            title: const Text('Create New Playlist',
                style: TextStyle(color: AppTheme.primaryColor)),
            onTap: () {
              Navigator.pop(context, '__create_new__');
            },
          ),
        ],
      ),
    );
  }
}
