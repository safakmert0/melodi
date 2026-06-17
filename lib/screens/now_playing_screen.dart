import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../core/extensions/duration_ext.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../services/lyrics_service.dart';
import '../services/artwork_service.dart';
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
  bool _showLyrics = true;
  String? _lastSongId;
  Color _dynamicColor = AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    super.dispose();
  }

  Future<void> _extractColor(Uint8List? bytes) async {
    if (bytes == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        maximumColorCount: 5,
      );
      final dominant = palette.dominantColor?.color;
      if (dominant != null && mounted) {
        setState(() => _dynamicColor = dominant);
      }
    } catch (_) {}
  }

  void _autoFetch(SongModel song) {
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;
    _extractColor(song.albumArt);
    if (song.lyrics == null || song.lyrics!.isEmpty) {
      Future.microtask(() => _fetchLyrics(song));
    }
    if (song.albumArt == null) {
      Future.microtask(() => _fetchArtwork(song));
    }
  }

  Future<void> _fetchLyrics(SongModel song) async {
    final result = await LyricsService.fetchLyrics(
      artist: song.artist,
      track: song.title,
    );
    if (result != null && mounted) {
      final updated = song.copyWith(lyrics: result);
      context.read<PlayerProvider>().updateCurrentSong(updated);
      context.read<LibraryProvider>().updateSong(updated);
    }
  }

  Future<void> _fetchArtwork(SongModel song) async {
    if (song.album.isEmpty) return;
    final result = await ArtworkService.fetchArtwork(
      artist: song.artist,
      album: song.album,
    );
    if (result != null && mounted) {
      final updated = song.copyWith(albumArt: result);
      context.read<PlayerProvider>().updateCurrentSong(updated);
      context.read<LibraryProvider>().updateSong(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, LocaleNotifier>(
      builder: (context, player, locale, _) {
        final song = player.currentSong;
        if (song != null) _autoFetch(song);
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

        final hasArt = song.albumArt != null && song.albumArt!.isNotEmpty;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              player.queue.length > 1
                  ? '${AppLocale.tr('now_playing_queue')} (${player.currentIndex + 1}/${player.queue.length})'
                  : '',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.more_horiz_rounded, color: Colors.white70),
                onPressed: () => _showOptions(context, player),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (hasArt) ...[
                Positioned.fill(
                  child: Image.memory(
                    song.albumArt!,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ] else
                Container(color: AppTheme.background),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Album Art - centered with glow
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: _dynamicColor.withValues(alpha: 0.4),
                                    blurRadius: 60,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: hasArt
                                    ? Image.memory(
                                        song.albumArt!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildArtFallback(),
                                      )
                                    : _buildArtFallback(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Song Title + Artist + Favorite
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
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
                                  color: isFav ? _dynamicColor : Colors.white54,
                                  size: 26,
                                ),
                                onPressed: () => lib.toggleFavorite(song),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lyrics
                    if (song.lyrics != null &&
                        song.lyrics!.isNotEmpty &&
                        _showLyrics)
                      _buildLyricsView(song.lyrics!, player)
                    else
                      const SizedBox(height: 16),
                    // Seek Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: MelodiSeekBar(
                        position: player.position,
                        duration: player.duration,
                        bufferedPosition: player.handler.bufferedPosition,
                        onSeek: player.seek,
                        activeColor: _dynamicColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Time labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            player.position.toFormattedString(),
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            player.duration.toFormattedString(),
                            style: TextStyle(
                              color: Colors.white54,
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
                              color: player.isShuffled ? _dynamicColor : Colors.white54,
                              size: 24,
                            ),
                            onPressed: player.toggleShuffle,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32),
                            onPressed: player.skipToPrevious,
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _dynamicColor,
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 40,
                              ),
                              onPressed: player.playPause,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                            onPressed: player.skipToNext,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.repeat_rounded,
                              color: player.repeatMode != LoopStyle.off ? _dynamicColor : Colors.white54,
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
                          style: TextStyle(
                            color: _dynamicColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Bottom row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SpeedButton(
                              player: player, speedOptions: _speedOptions, accentColor: _dynamicColor),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.closed_caption_rounded,
                                  color: _showLyrics ? _dynamicColor : Colors.white54,
                                  size: 22,
                                ),
                                onPressed: () {
                                  if (song.lyrics != null && song.lyrics!.isNotEmpty) {
                                    setState(() => _showLyrics = !_showLyrics);
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.queue_music_rounded, color: Colors.white54, size: 22),
                                onPressed: () => _showQueue(context),
                              ),
                            ],
                          ),
                          _VolumeBoostButton(
                            player: player,
                            showSlider: _showVolumeSlider,
                            onToggle: () => setState(() => _showVolumeSlider = !_showVolumeSlider),
                            accentColor: _dynamicColor,
                          ),
                        ],
                      ),
                    ),
                    if (_showVolumeSlider)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Icon(Icons.volume_down_rounded, color: Colors.white54, size: 16),
                            Expanded(
                              child: Slider(
                                value: player.volumeBoost.clamp(0.5, 2.0),
                                min: 0.5,
                                max: 2.0,
                                onChanged: (v) => player.setVolume(v),
                                activeColor: _dynamicColor,
                                inactiveColor: Colors.white24,
                              ),
                            ),
                            Icon(Icons.volume_up_rounded, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_LyricsLine> _parseLrc(String lyrics) {
    final lrcRegex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)');
    final lines = lyrics.split('\n');
    final result = <_LyricsLine>[];
    for (final line in lines) {
      final match = lrcRegex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();
        result.add(_LyricsLine(
          timestamp: Duration(
              milliseconds: minutes * 60000 + seconds * 1000 + millis),
          text: text,
        ));
      }
    }
    return result;
  }

  Widget _buildLyricsView(String lyrics, PlayerProvider player) {
    final parsed = _parseLrc(lyrics);
    final hasTimestamps = parsed.isNotEmpty;
    final lines = lyrics.split('\n');
    final positionMs = player.position.inMilliseconds;

    String currentText = '';
    String nextText = '';
    if (hasTimestamps) {
      int currentIndex = -1;
      for (int i = 0; i < parsed.length; i++) {
        if (parsed[i].timestamp.inMilliseconds <= positionMs) {
          currentIndex = i;
        } else {
          break;
        }
      }
      if (currentIndex >= 0) {
        currentText = parsed[currentIndex].text;
        if (currentIndex + 1 < parsed.length) {
          nextText = parsed[currentIndex + 1].text;
        }
      }
    } else {
      final totalMs = player.duration.inMilliseconds;
      final progress = totalMs > 0 ? positionMs / totalMs : 0.0;
      final currentLineIndex =
          (progress * lines.length).clamp(0, lines.length - 1).toInt();
      currentText = lines[currentLineIndex].trim();
      if (currentLineIndex + 1 < lines.length) {
        nextText = lines[currentLineIndex + 1].trim();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: currentText.isNotEmpty ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentText.isNotEmpty ? currentText : '♪',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (nextText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              nextText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ],
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
            style: TextStyle(color: AppTheme.textPrimary)),
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
                style: TextStyle(color: AppTheme.textSecondary)),
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
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSong(BuildContext context, SongModel song) async {
    final file = File(song.filePath);
    if (await file.exists()) {
      try {
        final dir = await getTemporaryDirectory();
        final shareDir = Directory('${dir.path}/share');
        if (!await shareDir.exists()) await shareDir.create();
        final ext = song.filePath.split('.').last;
        final shareFile = File('${shareDir.path}/${song.title}.$ext');
        await file.copy(shareFile.path);
        await Share.shareXFiles(
          [XFile(shareFile.path)],
          subject: '${song.title} - ${song.artist}',
        );
      } catch (e) {
        debugPrint('Share error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocale.tr('share')),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
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
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...durations.map((minutes) {
              final label = '$minutes ${AppLocale.tr('seconds')}';
              return ListTile(
                leading: Icon(Icons.timer_outlined, color: AppTheme.textSecondary),
                title: Text(label,
                    style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(
                  minutes >= 60
                      ? '${minutes ~/ 60} ${AppLocale.tr('hr')} ${minutes % 60} ${AppLocale.tr('min')}'
                      : '$minutes ${AppLocale.tr('min')}',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
                onTap: () {
                  final timerDuration = Duration(minutes: minutes);
                  player.handler.setSleepTimer(timerDuration);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${AppLocale.tr('sleep_timer')}: $label'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
              );
            }),
            ListTile(
              leading: Icon(Icons.close, color: AppTheme.errorColor),
              title: Text(AppLocale.tr('off'),
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                player.handler.setSleepTimer(Duration.zero);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocale.tr('sleep_timer_canceled')),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
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
              leading: Icon(Icons.playlist_add, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('add_to_playlist'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song!);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('song_info'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showSongInfo(context, song!);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('share'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('share_file'),
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _shareSong(context, song!);
              },
            ),
            ListTile(
              leading: Icon(Icons.timer, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('sleep_timer'),
                  style: TextStyle(color: AppTheme.textPrimary)),
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

class _LyricsLine {
  final Duration timestamp;
  final String text;
  const _LyricsLine({required this.timestamp, required this.text});
}

class _SpeedButton extends StatelessWidget {
  final PlayerProvider player;
  final List<double> speedOptions;
  final Color accentColor;

  const _SpeedButton({
    required this.player,
    required this.speedOptions,
    required this.accentColor,
  });

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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              '${currentSpeed.toStringAsFixed(2)}x'.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''),
              style: TextStyle(
                color: Colors.white,
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
  final Color accentColor;

  const _VolumeBoostButton({
    required this.player,
    required this.showSlider,
    required this.onToggle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: showSlider ? accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showSlider ? accentColor : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_up_rounded,
              color: showSlider ? accentColor : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${(player.volumeBoost * 100).round()}%',
              style: TextStyle(
                color: showSlider ? accentColor : Colors.white,
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
