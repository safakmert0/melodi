import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/melodi_design.dart';
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
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AspectRatio(
            aspectRatio: 1.18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MelodiRadius.panel),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (song.albumArt != null)
                    Image.memory(song.albumArt!, fit: BoxFit.cover)
                  else
                    const MelodiArtworkFallback(borderRadius: 0),
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
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: const Text(
                                'ŞİMDİ SENİN İÇİN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'LISTEN NOW',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
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
                        const SizedBox(height: 18),
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
