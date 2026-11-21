import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../theme/melodi_theme.dart';

/// MiniPlayer widget — InnerTune benzeri genişletilebilir alt çubuk
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        final isPlaying = player.isPlaying;
        final progress = player.position;
        final duration = player.duration ?? Duration.zero;

        return Material(
          elevation: 8,
          color: MelodiTheme.surface,
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song.albumArt != null && song.albumArt!.isNotEmpty
                      ? Image.memory(
                          song.albumArt!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MelodiTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MelodiTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress bar
                SizedBox(
                  width: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatDuration(progress),
                        style: const TextStyle(
                          fontSize: 10,
                          color: MelodiTheme.onSurfaceVariant,
                        ),
                      ),
                      LinearProgressIndicator(
                        value: duration.inMilliseconds > 0
                            ? progress.inMilliseconds / duration.inMilliseconds
                            : 0,
                        minHeight: 2,
                        backgroundColor: MelodiTheme.outlineVariant,
                        valueColor: const AlwaysStoppedAnimation(MelodiTheme.primary),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          fontSize: 10,
                          color: MelodiTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: MelodiTheme.onSurface,
                        size: 28,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          player.handler.pause();
                        } else {
                          player.handler.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: MelodiTheme.onSurface, size: 24),
                      onPressed: () => player.handler.skipToNext(),
                    ),
                  ],
                ),
                // Expand handle
                GestureDetector(
                  onTap: () => _expandNowPlaying(context),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.keyboard_arrow_up, color: MelodiTheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: MelodiTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note, color: MelodiTheme.onSurfaceVariant, size: 24),
      );

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _expandNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NowPlayingSheet(),
    );
  }
}

/// Now Playing Sheet — Expanded player (InnerTune benzeri)
class NowPlayingSheet extends StatelessWidget {
  const NowPlayingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        final isPlaying = player.isPlaying;
        final progress = player.position;
        final duration = player.duration ?? Duration.zero;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: MelodiTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MelodiTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Album art
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Album art with animation
                          Hero(
                            tag: 'albumArt',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: song.albumArt != null && song.albumArt!.isNotEmpty
                                  ? Image.memory(
                                      song.albumArt!,
                                      width: 280,
                                      height: 280,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 280,
                                      height: 280,
                                      decoration: BoxDecoration(
                                        color: MelodiTheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.music_note, size: 80, color: MelodiTheme.onSurfaceVariant),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Track info
                          Text(
                            song.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: MelodiTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            song.artist,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: MelodiTheme.onSurfaceVariant,
                            ),
                          ),
                          if (song.album != null && song.album!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              song.album!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: MelodiTheme.outline,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          // Progress bar
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(player.position), style: const TextStyle(fontSize: 12, color: MelodiTheme.onSurfaceVariant)),
                                  Text(_formatDuration(player.duration ?? Duration.zero), style: const TextStyle(fontSize: 12, color: MelodiTheme.onSurfaceVariant)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: MelodiTheme.primary,
                                  inactiveTrackColor: MelodiTheme.outlineVariant,
                                  thumbColor: MelodiTheme.primary,
                                  overlayColor: MelodiTheme.primary.withValues(alpha: 0.2),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: (duration.inMilliseconds > 0)
                                      ? (progress.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (value) {
                                    player.handler.seek(Duration(milliseconds: (value * (duration.inMilliseconds)).round()));
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shuffle, size: 24),
                                color: player.isShuffled ? MelodiTheme.primary : MelodiTheme.onSurfaceVariant,
                                onPressed: () => player.handler.toggleShuffle(),
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                icon: const Icon(Icons.skip_previous, size: 36),
                                color: MelodiTheme.onSurface,
                                onPressed: () => player.handler.skipToPrevious(),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: MelodiTheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: MelodiTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    size: 36,
                                    color: MelodiTheme.onPrimary,
                                  ),
                                  onPressed: () {
                                    if (isPlaying) {
                                      player.handler.pause();
                                    } else {
                                      player.handler.play();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.skip_next, size: 36),
                                color: MelodiTheme.onSurface,
                                onPressed: () => player.handler.skipToNext(),
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                icon: Icon(
                                  player.repeatMode.name == 'all' ? Icons.repeat :
                                  player.repeatMode.name == 'one' ? Icons.repeat_one : Icons.repeat,
                                size: 24),
                                color: player.repeatMode.name != 'off' ? MelodiTheme.primary : MelodiTheme.onSurfaceVariant,
                                onPressed: () {
                                  final current = player.repeatMode;
                                  AudioServiceRepeatMode next;
                                  if (current.name == 'off') {
                                    next = AudioServiceRepeatMode.all;
                                  } else if (current.name == 'all') {
                                    next = AudioServiceRepeatMode.one;
                                  } else {
                                    next = AudioServiceRepeatMode.none;
                                  }
                                  player.handler.setRepeatMode(next);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Secondary controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.queue_music, size: 24),
                                color: MelodiTheme.onSurfaceVariant,
                                onPressed: () => _showQueue(context),
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                icon: const Icon(Icons.lyrics, size: 24),
                                color: MelodiTheme.onSurfaceVariant,
                                onPressed: () => _showLyrics(context),
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                icon: const Icon(Icons.timer, size: 24),
                                color: MelodiTheme.onSurfaceVariant,
                                onPressed: () => _showSleepTimer(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQueue(BuildContext context) {}
  void _showLyrics(BuildContext context) {}
  void _showSleepTimer(BuildContext context) {}
}