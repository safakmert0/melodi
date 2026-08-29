import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../image_with_fallback.dart';

class HomeContinueListening extends StatelessWidget {
  const HomeContinueListening({super.key, required this.library});

  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong ??
            (library.recent.isNotEmpty
                ? library.recent.first
                : library.songs.first);
        final queue = library.recent.isNotEmpty
            ? library.recent
            : library.mostPlayed.isNotEmpty
                ? library.mostPlayed
                : library.songs;
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ArtworkImage(
                  imageBytes: song.albumArt,
                  title: song.title,
                  size: 72,
                  borderRadius: 8,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ŞİMDİ SENİN İÇİN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${song.artist} · ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _play(
                              player: player,
                              queue: queue,
                              songId: song.id,
                            ),
                            icon: Icon(
                              player.currentSong?.id == song.id &&
                                      player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Dinle'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Karıştır',
                            onPressed: () async {
                              await player.playFromQueue(queue, 0);
                              if (!player.isShuffled) {
                                await player.toggleShuffle();
                              }
                            },
                            icon: const Icon(Icons.shuffle_rounded, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _play({
    required PlayerProvider player,
    required List<dynamic> queue,
    required String songId,
  }) {
    if (player.currentSong?.id == songId) {
      player.playPause();
      return;
    }
    final index = max(0, queue.indexWhere((song) => song.id == songId));
    player.playFromQueue(queue.cast(), index);
  }
}
