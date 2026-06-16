import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/localization.dart';
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
    return Consumer2<PlayerProvider, LocaleNotifier>(
      builder: (context, player, locale, _) {
        final song = player.currentSong;
        if (song == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                AppLocale.tr('now_playing'),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note_rounded, size: 80, color: AppTheme.textTertiary),
                  const SizedBox(height: 24),
                  Text(
                    AppLocale.tr('no_song_playing'),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppLocale.tr('now_playing'),
              style: const TextStyle(
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
                              inactiveColor: AppTheme.divider,
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
                            ? AppLocale.tr('repeat_all')
                            : AppLocale.tr('repeat_one'),
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
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocale.tr('output_selection')),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            );
                          },
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
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocale.tr('device_selection')),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            );
                          },
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

  String _stripLrcTimestamp(String line) {
    return line.replaceAll(RegExp(r'^\[\d{2}:\d{2}(\.\d{2,3})?\]\s*'), '');
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
                  ? _stripLrcTimestamp(lines[currentLineIndex])
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
                  ? _stripLrcTimestamp(lines[currentLineIndex + 1])
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
            AppTheme.card,
            AppTheme.cardHover,
          ],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 80,
        color: AppTheme.textTertiary,
      ),
    );
  }

  void _showSongInfo(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(song.title,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(AppLocale.tr('artist_label'), song.artist),
            _infoRow(AppLocale.tr('album_label'), song.album),
            if (song.genre != null) _infoRow(AppLocale.tr('genre_label'), song.genre!),
            if (song.year != null) _infoRow(AppLocale.tr('year_label'), '${song.year}'),
            if (song.trackNumber != null) _infoRow(AppLocale.tr('track_label'), '${song.trackNumber}'),
            if (song.bitrate != null) _infoRow(AppLocale.tr('bitrate_label'), '${song.bitrate} kbps'),
            _infoRow(AppLocale.tr('duration_label'), song.duration.toFormattedString()),
            _infoRow(AppLocale.tr('file_label'), song.filePath.split('/').last),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _shareSong(BuildContext context, SongModel song) {
    final file = File(song.filePath);
    if (file.existsSync()) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 48),
                const SizedBox(height: 16),
                Text(AppLocale.tr('share'),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(song.title,
                    style: const TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${song.title} - ${AppLocale.tr('share')}'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share),
                  label: Text(AppLocale.tr('share')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showSleepTimer(BuildContext context, PlayerProvider player) {
    final durations = [
      5, 10, 15, 30, 45, 60, 90, 120
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('sleep_timer'),
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...durations.map((minutes) {
              final label = '$minutes ${AppLocale.tr('seconds')}';
              return ListTile(
                title: Text(label,
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  final timerDuration = Duration(minutes: minutes);
                  player.handler.setSleepTimer(timerDuration);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
              );
            }),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.errorColor),
              title: Text(AppLocale.tr('off'),
                  style: const TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                player.handler.setSleepTimer(Duration.zero);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
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
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('add_to_playlist'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('song_info'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showSongInfo(context, song!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('share'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _shareSong(context, song!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('sleep_timer'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showSleepTimer(context, player);
              },
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
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider),
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
          color: showSlider ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showSlider ? AppTheme.primaryColor : AppTheme.divider,
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
