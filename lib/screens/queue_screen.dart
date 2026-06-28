import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocale.tr('queue'),
          style: MelodiTheme.heading(size: 16).copyWith(letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final queue = player.queue;
          final currentIndex = player.currentIndex;

          if (queue.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded, size: 64, color: MelodiTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    AppLocale.tr('queue_empty'),
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          final currentSong = currentIndex < queue.length ? queue[currentIndex] : null;
          final nextUp = currentIndex + 1 < queue.length
              ? queue.sublist(currentIndex + 1)
              : <SongModel>[];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (currentSong != null)
                SliverToBoxAdapter(
                  child: _buildSectionHeader(AppLocale.tr('now_playing')),
                ),
              if (currentSong != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: MelodiTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _QueueTile(
                      song: currentSong,
                      isCurrent: true,
                      index: null,
                    ),
                  ),
                ),
              if (nextUp.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildSectionHeader(AppLocale.tr('next_up')),
                ),
              if (nextUp.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = nextUp[index];
                      return _QueueTile(
                        song: song,
                        isCurrent: false,
                        index: currentIndex + 1 + index,
                      );
                    },
                    childCount: nextUp.length,
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: MelodiTheme.label(size: 12, letterSpacing: 0.1),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final SongModel song;
  final bool isCurrent;
  final int? index;

  const _QueueTile({
    required this.song,
    required this.isCurrent,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent)
            Icon(Icons.bar_chart_rounded, size: 20, color: MelodiTheme.primaryGreen)
          else if (index != null)
            SizedBox(
              width: 24,
              child: Text(
                '$index',
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: MelodiTheme.surfaceMid2,
            ),
            child: song.albumArt != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(song.albumArt!, fit: BoxFit.cover, gaplessPlayback: true),
                  )
                : const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant),
          ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppConstants.fontFamily,
          color: isCurrent ? MelodiTheme.primaryGreen : MelodiTheme.onSurface,
          fontSize: 15,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppConstants.fontFamily,
          color: MelodiTheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.drag_handle_rounded, color: MelodiTheme.onSurfaceVariant),
        onPressed: () {},
      ),
    );
  }
}
