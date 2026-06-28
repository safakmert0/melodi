import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/extensions/duration_ext.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'image_with_fallback.dart';
import 'seek_bar.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;

        return GestureDetector(
          onTap: song != null
              ? () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        );
                      },
                      fullscreenDialog: true,
                    ),
                  );
                }
              : null,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: AppConstants.miniPlayerHeight,
                decoration: BoxDecoration(
                  color: MelodiTheme.containerLow.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(0, -2),
                      blurRadius: 8,
                    ),
                  ],
                  border: Border(
                    top: BorderSide(
                      color: MelodiTheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: song != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CompactSeekBar(
                            position: player.position,
                            duration: player.duration,
                            activeColor: MelodiTheme.primaryGreen,
                            onChanged: (value) {
                              final pos = Duration(
                                milliseconds: (value * player.duration.inMilliseconds).round(),
                              );
                              player.seek(pos);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'album_art_${song.id}',
                                  child: ArtworkImage(
                                    imageBytes: song.albumArt,
                                    title: song.title,
                                    size: 44,
                                    borderRadius: 4,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                          fontFamily: AppConstants.fontFamily,
                                          color: MelodiTheme.onSurface,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: AppConstants.fontFamily,
                                          color: MelodiTheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded),
                                  color: MelodiTheme.onSurface,
                                  iconSize: 24,
                                  onPressed: player.skipToPrevious,
                                ),
                                IconButton(
                                  icon: Icon(
                                    player.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded,
                                  ),
                                  color: MelodiTheme.primaryGreen,
                                  iconSize: 32,
                                  onPressed: player.playPause,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded),
                                  color: MelodiTheme.onSurface,
                                  iconSize: 24,
                                  onPressed: player.skipToNext,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note_rounded, size: 20, color: MelodiTheme.textMuted),
                            const SizedBox(width: 8),
                            Text(
                              AppLocale.tr('no_music_playing'),
                              style: const TextStyle(
                                fontFamily: AppConstants.fontFamily,
                                color: MelodiTheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
