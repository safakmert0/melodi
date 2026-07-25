import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/melodi_design.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';

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
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: AspectRatio(
            aspectRatio: 1.7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MelodiRadius.panel),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (song.albumArt != null)
                    Image.memory(song.albumArt!, fit: BoxFit.cover)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x16000000), Color(0xE9000000)],
                        stops: [0.18, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'KALDIĞIN YERDEN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${song.artist} · ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                              ),
                              label: const Text('Dinle'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'Karıştır',
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.14),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await player.playFromQueue(queue, 0);
                                if (!player.isShuffled) {
                                  await player.toggleShuffle();
                                }
                              },
                              icon: const Icon(Icons.shuffle_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
