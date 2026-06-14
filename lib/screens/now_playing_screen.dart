import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/extensions/duration_ext.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../widgets/seek_bar.dart';
import '../widgets/image_with_fallback.dart';
import '../widgets/queue_sheet.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  bool _showVolumeSlider = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return const Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
              child: Text(
                'No song playing',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Now Playing',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AppTheme.textSecondary),
                onPressed: () => _showOptions(context, player),
              ),
            ],
          ),
          body: ArtworkBackground(
            imageBytes: song.albumArt,
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Album Art
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: song.albumArt != null
                              ? Image.memory(
                                  song.albumArt!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildArtFallback(),
                                )
                              : _buildArtFallback(),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Lyrics section (or song info if no lyrics)
                  _buildLyricsOrInfo(song, player),
                  const SizedBox(height: 8),
                  // Playback speed and volume boost row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SpeedButton(player: player, speedOptions: _speedOptions),
                        const SizedBox(width: 16),
                        _VolumeBoostButton(
                          player: player,
                          showSlider: _showVolumeSlider,
                          onToggle: () => setState(() => _showVolumeSlider = !_showVolumeSlider),
                        ),
                      ],
                    ),
                  ),
                  if (_showVolumeSlider)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down_rounded,
                              color: AppTheme.textTertiary, size: 16),
                          Expanded(
                            child: Slider(
                              value: player.volumeBoost.clamp(0.5, 2.0),
                              min: 0.5,
                              max: 2.0,
                              onChanged: (v) => player.setVolume(v),
                              activeColor: AppTheme.primaryColor,
                              inactiveColor: AppTheme.darkDivider,
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded,
                              color: AppTheme.textTertiary, size: 16),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Seek Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: MelodiSeekBar(
                      position: player.position,
                      duration: player.duration,
                      bufferedPosition: player.handler.bufferedPosition,
                      onSeek: player.seek,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Time labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          player.position.toFormattedString(),
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          player.duration.toFormattedString(),
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Main controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: player.isShuffled
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded,
                              color: AppTheme.textPrimary, size: 32),
                          onPressed: player.skipToPrevious,
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor,
                          ),
                          child: IconButton(
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 36,
                            ),
                            onPressed: player.playPause,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded,
                              color: AppTheme.textPrimary, size: 32),
                          onPressed: player.skipToNext,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.repeat_rounded,
                            color: player.repeatMode != LoopStyle.off
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: player.cycleRepeatMode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Repeat mode indicator
                  if (player.repeatMode != LoopStyle.off)
                    Center(
                      child: Text(
                        player.repeatMode == LoopStyle.all
                            ? 'Repeat All'
                            : 'Repeat One',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const Spacer(flex: 1),
                  // Bottom row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.speaker_group_rounded,
                              color: AppTheme.textSecondary, size: 22),
                          onPressed: () {},
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                player.autoShuffleEnabled
                                    ? Icons.auto_graph_rounded
                                    : Icons.auto_graph_outlined,
                                color: player.autoShuffleEnabled
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                size: 22,
                              ),
                              onPressed: () =>
                                  player.setAutoShuffle(!player.autoShuffleEnabled),
                            ),
                            IconButton(
                              icon: const Icon(Icons.queue_music_rounded,
                                  color: AppTheme.textSecondary, size: 22),
                              onPressed: () => _showQueue(context),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.devices_rounded,
                              color: AppTheme.textSecondary, size: 22),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricsOrInfo(SongModel song, PlayerProvider player) {
    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      return _buildLyricsView(song.lyrics!, player);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Consumer<LibraryProvider>(
            builder: (context, lib, _) {
              final isFav = lib.favorites.any((s) => s.id == song.id);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav
                      ? AppTheme.favoriteColor
                      : AppTheme.textTertiary,
                  size: 28,
                ),
                onPressed: () => lib.toggleFavorite(song),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView(String lyrics, PlayerProvider player) {
    final lines = lyrics.split('\n');
    final positionMs = player.position.inMilliseconds;
    final totalMs = player.duration.inMilliseconds;
    final progress = totalMs > 0 ? positionMs / totalMs : 0.0;
    final currentLineIndex = (progress * lines.length).clamp(0, lines.length - 1).toInt();

    return SizedBox(
      height: 80,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentLineIndex < lines.length
                  ? lines[currentLineIndex].trim()
                  : '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentLineIndex + 1 < lines.length
                  ? lines[currentLineIndex + 1].trim()
                  : '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkCard,
            AppTheme.darkCardHover,
          ],
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        size: 80,
        color: AppTheme.textTertiary,
      ),
    );
  }

  void _showOptions(BuildContext context, PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
              title: const Text('Add to Playlist',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
              title: const Text('Song Info',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: AppTheme.textSecondary),
              title: const Text('Share',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: AppTheme.textSecondary),
              title: const Text('Sleep Timer',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, SongModel song) {
    final playlistProvider = context.read<PlaylistProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPlaylistSheet(
        song: song,
        playlists: playlistProvider.playlists,
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QueueSheet(),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final PlayerProvider player;
  final List<double> speedOptions;

  const _SpeedButton({required this.player, required this.speedOptions});

  @override
  Widget build(BuildContext context) {
    final currentSpeed = player.playbackSpeed;
    return GestureDetector(
      onTap: () {
        final idx = speedOptions.indexOf(currentSpeed);
        final nextIdx = (idx + 1) % speedOptions.length;
        player.setPlaybackSpeed(speedOptions[nextIdx]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.darkDivider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, color: AppTheme.textSecondary, size: 16),
            const SizedBox(width: 4),
            Text(
              '${currentSpeed.toStringAsFixed(2)}x'.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeBoostButton extends StatelessWidget {
  final PlayerProvider player;
  final bool showSlider;
  final VoidCallback onToggle;

  const _VolumeBoostButton({
    required this.player,
    required this.showSlider,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: showSlider ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showSlider ? AppTheme.primaryColor : AppTheme.darkDivider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_up_rounded,
              color: showSlider ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${(player.volumeBoost * 100).round()}%',
              style: TextStyle(
                color: showSlider ? AppTheme.primaryColor : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
