import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'image_with_fallback.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;

        return GestureDetector(
          onTap: song != null
              ? () => Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const NowPlayingScreen(),
                  transitionsBuilder: (_, animation, __, child) => SlideTransition(
                    position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child),
                  fullscreenDialog: true))
              : null,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: MelodiTheme.containerLow.withOpacity(0.85),
                  border: Border(
                    top: BorderSide(color: MelodiTheme.outlineVariant.withOpacity(0.3), width: 0.5)),
                ),
                child: song != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            child: LinearProgressIndicator(
                              value: player.duration.inMilliseconds > 0
                                  ? player.position.inMilliseconds / player.duration.inMilliseconds : 0,
                              minHeight: 2,
                              backgroundColor: MelodiTheme.surfaceBright,
                              valueColor: const AlwaysStoppedAnimation<Color>(MelodiTheme.primaryGreen),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'album_art_${song.id}',
                                    child: ArtworkImage(
                                      imageBytes: song.albumArt, title: song.title,
                                      size: 44, borderRadius: 4),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                            color: MelodiTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                                        Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                            color: MelodiTheme.onSurfaceVariant, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cast_rounded, size: 20),
                                    color: MelodiTheme.onSurfaceVariant,
                                    onPressed: () {}),
                                  IconButton(
                                    icon: Icon(
                                      player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                      size: 32),
                                    color: MelodiTheme.primaryGreen,
                                    onPressed: player.playPause),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_note_rounded, size: 20, color: MelodiTheme.textMuted),
                            const SizedBox(width: 8),
                            Text(AppLocale.tr('no_music_playing'),
                              style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                color: MelodiTheme.onSurfaceVariant, fontSize: 14)),
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
