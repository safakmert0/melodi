import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/melodi_design.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../screens/queue_screen.dart';
import 'image_with_fallback.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        final theme = Theme.of(context);

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Material(
              color: theme.colorScheme.surface .withOpacity(0.9),
              child: InkWell(
                onTap: song == null ? null : () => _openPlayer(context),
                child: AnimatedSize(
                  duration: MelodiMotion.standard,
                  curve: MelodiMotion.expressive,
                  child: song == null
                      ? const _IdleMiniPlayer()
                      : Semantics(
                          label: '${song.title}, ${song.artist}',
                          hint: 'Tam oynatıcıyı aç',
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if (velocity.abs() < 180) return;
                              HapticFeedback.selectionClick();
                              if (velocity < 0) {
                                player.skipToNext();
                              } else {
                                player.skipToPrevious();
                              }
                            },
                            child: SizedBox(
                              height: 72,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.primary
                                                 .withOpacity(0.09),
                                            Colors.transparent,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: theme.colorScheme.onSurface
                                               .withOpacity(0.08),
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      8,
                                      5,
                                      7,
                                    ),
                                    child: Row(
                                      children: [
                                        Hero(
                                          tag: 'album_art_${song.id}',
                                          child: ArtworkImage(
                                            imageBytes: song.albumArt,
                                            title: song.title,
                                            size: 56,
                                            borderRadius: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${song.artist} · ${_sourceLabel(song.filePath)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.labelMedium
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Kuyruk',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.queue_music_rounded,
                                            size: 21,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const QueueScreen(),
                                            ),
                                          ),
                                        ),
                                        IconButton.filled(
                                          tooltip: player.isPlaying
                                              ? 'Duraklat'
                                              : 'Oynat',
                                          visualDensity: VisualDensity.compact,
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            foregroundColor:
                                                theme.colorScheme.onPrimary,
                                          ),
                                          icon: Icon(
                                            player.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 25,
                                          ),
                                          onPressed: player.playPause,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    left: 20,
                                    right: 20,
                                    bottom: 0,
                                    child: _MiniProgress(
                                      position: player.position,
                                      duration: player.duration,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _sourceLabel(String path) {
    if (path.startsWith('youtube://')) return 'YouTube';
    if (path.startsWith('spotify://')) return 'Spotify';
    if (path.startsWith('http')) return 'Çevrimiçi';
    return 'Bu aygıt';
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final value =
        total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2.5,
        backgroundColor:
            Theme.of(context).colorScheme.onSurface .withOpacity(0.08),
      ),
    );
  }
}

class _IdleMiniPlayer extends StatelessWidget {
  const _IdleMiniPlayer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.onSurface .withOpacity(0.07),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Bir şarkı seç ve Melodi başlasın',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
