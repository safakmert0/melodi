import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../services/audio_handler.dart';
import '../models/song_model.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final queue = player.queue;
          final currentIndex = player.currentIndex;
          final currentSong = currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;
          final nextUp = currentIndex + 1 < queue.length ? queue.sublist(currentIndex + 1) : <SongModel>[];

          return Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                        color: MelodiTheme.onSurface,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text('Queue', textAlign: TextAlign.center,
                          style: MelodiTheme.heading(size: 16).copyWith(letterSpacing: 0.5)),
                      ),
                      TextButton(
                        onPressed: () => player.clearQueue(),
                        child: Text('CLEAR', style: MelodiTheme.label(
                          color: MelodiTheme.primaryGreen, letterSpacing: 0.1)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (currentSong != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text('NOW PLAYING',
                            style: MelodiTheme.label(letterSpacing: 0.1)),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MelodiTheme.containerHigh.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: MelodiTheme.outlineVariant, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (currentSong.albumArt != null)
                                      ClipRRect(borderRadius: BorderRadius.circular(4),
                                        child: Image.memory(currentSong.albumArt!,
                                          width: 48, height: 48, fit: BoxFit.cover, gaplessPlayback: true))
                                    else
                                      Container(width: 48, height: 48, color: MelodiTheme.containerLow,
                                        child: const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant)),
                                    Positioned(
                                      left: 4, bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(color: MelodiTheme.primaryGreen, borderRadius: BorderRadius.circular(2)),
                                        child: const Icon(Icons.equalizer, size: 12, color: MelodiTheme.background),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(currentSong.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: AppConstants.fontFamily,
                                        color: MelodiTheme.primaryGreen, fontSize: 15, fontWeight: FontWeight.w600)),
                                    Text(currentSong.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                        color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(color: MelodiTheme.primaryGreen.withOpacity(0.4)),
                                  borderRadius: BorderRadius.circular(4)),
                                child: Text('HI-RES', style: MelodiTheme.label(
                                  size: 10, color: MelodiTheme.primaryGreen, letterSpacing: 0.08)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.more_vert_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (nextUp.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('NEXT UP', style: MelodiTheme.label(letterSpacing: 0.1)),
                              Text('${nextUp.length} Songs',
                                style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      SliverList(delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = nextUp[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                              child: song.albumArt != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(song.albumArt!, width: 48, height: 48,
                                        fit: BoxFit.cover, gaplessPlayback: true))
                                  : Container(color: MelodiTheme.containerHigh,
                                      child: const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant)),
                            ),
                            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                color: MelodiTheme.onSurface, fontSize: 15)),
                            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
                            trailing: const Icon(Icons.drag_handle_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
                          );
                        },
                        childCount: nextUp.length)),
                    ],
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                ),
              ),
              // Bottom bar with Shuffle + Repeat + Play
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: MelodiTheme.background,
                  border: Border(top: BorderSide(color: MelodiTheme.outlineVariant.withOpacity(0.3), width: 0.5)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => player.toggleShuffle(),
                        child: Row(
                          children: [
                            Icon(Icons.shuffle_rounded, size: 20,
                              color: player.isShuffled ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('Shuffle', style: TextStyle(
                              fontFamily: AppConstants.fontFamily,
                              color: player.isShuffled ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant,
                              fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: MelodiTheme.outlineVariant),
                      GestureDetector(
                        onTap: () => player.cycleRepeatMode(),
                        child: Row(
                          children: [
                            Icon(Icons.repeat_rounded, size: 20,
                              color: player.repeatMode != LoopStyle.off ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('Repeat', style: TextStyle(
                              fontFamily: AppConstants.fontFamily,
                              color: player.repeatMode != LoopStyle.off ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant,
                              fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => player.playPause(),
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MelodiTheme.primaryGreen,
                            boxShadow: [BoxShadow(
                              color: MelodiTheme.primaryGreen.withOpacity(0.4),
                              blurRadius: 12, spreadRadius: 2)],
                          ),
                          child: Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: MelodiTheme.background, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
