import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/share_service.dart';
import '../core/localization.dart';
import '../core/extensions/duration_ext.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../services/lyrics_service.dart';
import '../services/artwork_service.dart';
import '../services/download_manager.dart';
import '../services/database_service.dart';
import '../widgets/seek_bar.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/image_with_fallback.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/crossfade_slider.dart';
import 'lyrics_screen.dart';
import 'cover_flow_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  final PageController _surfaceController = PageController();
  bool _showVolumeSlider = false;
  String? _lastSongId;
  int _lyricsOffsetMs = 0;

  LyricsResult? _lyricsResult;
  List<LrcLine> _lyricsLines = [];
  bool _lyricsLoading = false;
  int _currentLineIndex = -1;
  Timer? _lyricsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _startLyricsTimer();
  }

  @override
  void dispose() {
    _lyricsTimer?.cancel();
    _surfaceController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    super.dispose();
  }

  void _startLyricsTimer() {
    _lyricsTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      final pos = player.position;
      final dur = player.duration;
      final clampedMs = dur.inMilliseconds > 0
          ? pos.inMilliseconds.clamp(0, dur.inMilliseconds)
          : pos.inMilliseconds;
      if (_lyricsLines.isNotEmpty) {
        final lyricPosition = LyricsTiming.lyricPositionMs(
          playbackPositionMs: clampedMs,
          manualOffsetMs: _lyricsOffsetMs,
          playbackDurationMs: dur.inMilliseconds,
          lyricsDurationMs: _lyricsResult?.durationMs ?? 0,
        );
        _updateCurrentLine(lyricPosition);
      }
    });
  }

  void _updateCurrentLine(int positionMs) {
    var idx = LyricsTiming.findLineIndex(_lyricsLines, positionMs);
    // If at end of song and no line matched, show last line
    if (idx == -1 && _lyricsLines.isNotEmpty) {
      final player = context.read<PlayerProvider>();
      if (player.duration.inMilliseconds > 0 &&
          positionMs >= player.duration.inMilliseconds - 1000) {
        idx = _lyricsLines.length - 1;
      }
    }
    if (idx != _currentLineIndex) {
      _currentLineIndex = idx;
      if (mounted) setState(() {});
    }
  }

  void _autoFetch(SongModel song) {
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;
    _lyricsResult = null;
    _lyricsLines = [];
    _lyricsLoading = true;
    _currentLineIndex = -1;
    _lyricsOffsetMs = 0;
    _loadLyricsOffset(song);
    // Delay lyrics fetch to ensure player has loaded the song duration
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && (song.lyrics == null || song.lyrics!.isEmpty)) {
        _fetchLyrics(song);
      } else if (mounted) {
        final text = song.lyrics!;
        final parsed = LrcParser.parse(text);
        if (parsed.isNotEmpty) {
          _lyricsLines = parsed;
          _lyricsResult = LyricsResult(syncedLrc: text);
          _lyricsLoading = false;
          setState(() {});
          // Refresh from cache/API as well so LRCLIB's source duration can
          // correct small timing drift in embedded synchronized lyrics.
          _fetchLyrics(song);
        } else {
          // Embedded/plain lyrics are still a useful fallback, but they must
          // not prevent a synchronized LRCLIB lookup.
          _lyricsResult = LyricsResult(plainText: text);
          setState(() {});
          _fetchLyrics(song);
        }
      }
    });
    if (song.albumArt == null) {
      Future.microtask(() => _fetchArtwork(song));
    }
  }

  Future<void> _loadLyricsOffset(SongModel song) async {
    final raw =
        await DatabaseService.instance.getSetting('lyrics_offset_${song.id}');
    if (!mounted || _lastSongId != song.id) return;
    setState(() => _lyricsOffsetMs = int.tryParse(raw ?? '') ?? 0);
  }

  Future<void> _fetchLyrics(SongModel song) async {
    // Use player's actual duration for accurate lyrics sync
    final actualDurationMs =
        context.read<PlayerProvider>().duration.inMilliseconds;
    final durationMs =
        actualDurationMs > 0 ? actualDurationMs : song.duration.inMilliseconds;
    final result = await LyricsService.fetchLyrics(
      artist: song.artist,
      track: song.title,
      album: song.album,
      durationMs: durationMs,
      filePath: song.filePath,
      preferSynced: true,
    );
    if (result != null && mounted) {
      _lyricsResult = result;
      if (result.syncedLrc != null) {
        _lyricsLines = LrcParser.parse(result.syncedLrc!);
      } else {
        _lyricsLines = [];
      }
      _currentLineIndex = -1;
      final lyricsText = result.syncedLrc ?? result.plainText;
      final updated = song.copyWith(lyrics: lyricsText);
      context.read<PlayerProvider>().updateCurrentSong(updated);
      context.read<LibraryProvider>().updateSong(updated);
      _lyricsLoading = false;
      setState(() {});
    } else if (mounted) {
      setState(() => _lyricsLoading = false);
    }
  }

  Future<void> _fetchArtwork(SongModel song) async {
    final result = await ArtworkService.fetchArtwork(
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
    );
    if (result != null && mounted) {
      if (_lastSongId != song.id) return;
      final updated = song.copyWith(albumArt: result);
      context.read<PlayerProvider>().updateCurrentSong(updated);
      final lib = context.read<LibraryProvider>();
      lib.updateSong(updated);
      // Cache artwork to database so it persists across refreshes
      lib.cacheArtwork(song.id, result);
      if (mounted) setState(() {});
    }
  }

  void _openCoverFlow() {
    final player = context.read<PlayerProvider>();
    if (player.queue.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CoverFlowScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    return Consumer2<PlayerProvider, LocaleNotifier>(
      builder: (context, player, locale, _) {
        final song = player.currentSong;
        if (song != null) _autoFetch(song);
        if (song == null) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 28, color: cs.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                AppLocale.tr('now_playing'),
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
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
                  Icon(Icons.music_note_rounded,
                      size: 80, color: cs.onSurfaceVariant),
                  const SizedBox(height: 24),
                  Text(
                    AppLocale.tr('no_song_playing'),
                    style: TextStyle(color: cs.onSurface, fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        final hasArt = song.albumArt != null && song.albumArt!.isNotEmpty;

        return GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 500) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                    child: Container(
                        color: Theme.of(context).colorScheme.surface)),
                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.expand_more_rounded,
                                size: 30,
                                color:
                                    Theme.of(context).colorScheme.onSurface),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  AppLocale.tr('now_playing').toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.more_vert_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            onPressed: () => _showOptions(context, player),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 48),
                      _buildPlayerSurface(song, player, hasArt),
                      const SizedBox(height: 6),
                      // Song Title + Artist
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: MelodiSeekBar(
                          position: player.duration.inMilliseconds > 0
                              ? Duration(
                                  milliseconds: player.position.inMilliseconds
                                      .clamp(0, player.duration.inMilliseconds))
                              : player.position,
                          duration: player.duration,
                          bufferedPosition: player.handler.bufferedPosition,
                          onSeek: player.seek,
                          activeColor:
                              Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Main controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: player.isShuffled
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              size: 22,
                            ),
                            onPressed: player.toggleShuffle,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons.skip_previous_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 36),
                            onPressed: player.skipToPrevious,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 36,
                              ),
                              onPressed: player.playPause,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(Icons.skip_next_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 36),
                            onPressed: player.skipToNext,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              Icons.repeat_rounded,
                              color: player.repeatMode != LoopStyle.off
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              size: 22,
                            ),
                            onPressed: player.cycleRepeatMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Supplementary actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SpeedButton(
                                player: player,
                                speedOptions: _speedOptions,
                                accentColor:
                                    Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Consumer<LibraryProvider>(
                              builder: (context, lib, _) {
                                final isFav =
                                    lib.favorites.any((s) => s.id == song.id);
                                return IconButton(
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFav
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    size: 22,
                                  ),
                                  onPressed: () => lib.toggleFavorite(song),
                                );
                              },
                            ),
                            Consumer<DownloadProvider>(
                              builder: (context, dl, _) {
                                final song =
                                    context.read<PlayerProvider>().currentSong;
                                final status = song != null
                                    ? dl.getStatusForSong(
                                        song.title, song.artist)
                                    : null;
                                final isDownloaded =
                                    status == DownloadState.completed;
                                final isDownloading =
                                    status == DownloadState.downloading ||
                                        status == DownloadState.pending;
                                return IconButton(
                                  icon: Icon(
                                    isDownloaded
                                        ? Icons.download_done_rounded
                                        : isDownloading
                                            ? Icons.hourglass_top_rounded
                                            : Icons.download_outlined,
                                    color: isDownloaded
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    size: 22,
                                  ),
                                  onPressed: isDownloaded || isDownloading
                                      ? null
                                      : () {
                                          if (song != null) {
                                            final spotifyId =
                                                song.id.startsWith('spotify:')
                                                    ? song.id.replaceFirst(
                                                        'spotify:', '')
                                                    : song.id;
                                            final sourceVideoId = song.filePath
                                                    .startsWith('youtube://')
                                                ? song.filePath.replaceFirst(
                                                    'youtube://', '')
                                                : RegExp(r'^[A-Za-z0-9_-]{11}$')
                                                        .hasMatch(song.id)
                                                    ? song.id
                                                    : null;
                                            final queued = dl.enqueueTrack(
                                              spotifyTrackId: spotifyId,
                                              title: song.title,
                                              artist: song.artist,
                                              album: song.album,
                                              sourceVideoId: sourceVideoId,
                                              expectedDurationMs:
                                                  song.duration.inMilliseconds,
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(queued
                                                    ? '${song.title} indiriliyor...'
                                                    : 'Bu şarkı zaten indirilmiş veya sırada'),
                                                backgroundColor: queued
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.queue_music_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 22),
                              onPressed: () => _showQueue(context),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.dark_mode_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 22,
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                  ),
                                  builder: (_) => const SleepTimerSheet(),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.equalizer_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 22),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                  ),
                                  builder: (_) => const EqualizerSheet(),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            _VolumeBoostButton(
                              player: player,
                              showSlider: _showVolumeSlider,
                              onToggle: () => setState(
                                  () => _showVolumeSlider = !_showVolumeSlider),
                              accentColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      if (_showVolumeSlider)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              Icon(Icons.volume_down_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 16),
                              Expanded(
                                child: Slider(
                                  value: player.volumeBoost.clamp(0.5, 2.0),
                                  min: 0.5,
                                  max: 2.0,
                                  onChanged: (v) => player.setVolume(v),
                                  activeColor:
                                      Theme.of(context).colorScheme.primary,
                                  inactiveColor: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              Icon(Icons.volume_up_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 16),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerSurface(
      SongModel song, PlayerProvider player, bool hasArt) {
    final screen = MediaQuery.sizeOf(context);
    final preferredHeight = screen.width + 16;
    final compactHeight = screen.height * 0.48;
    final surfaceHeight =
        preferredHeight < compactHeight ? preferredHeight : compactHeight;
    return SizedBox(
      height: surfaceHeight,
      child: PageView(
        controller: _surfaceController,
        children: [
          _buildArtworkSurface(song, hasArt),
          _buildLyricsSurface(player),
          _buildQueueSurface(player),
        ],
      ),
    );
  }

  Widget _buildArtworkSurface(SongModel song, bool hasArt) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                  child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _openCoverFlow,
                      child: Hero(
                        tag: 'album_art_${song.id}',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: hasArt
                                ? Image.memory(
                                    song.albumArt!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) =>
                                        _buildArtFallback(),
                                  )
                                : _buildArtFallback(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          child: Icon(
                            Icons.view_carousel_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildSingleLineLyrics(),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildLyricsSurface(PlayerProvider player) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LyricsScreen(
                lyricsDurationMs: _lyricsResult?.durationMs ?? 0,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lyrics_rounded,
                        size: 18, color: colors.onSurface),
                    const SizedBox(width: 8),
                    Text('Canlı sözler',
                        style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_lyricsLines.isNotEmpty)
                      Text('SENKRON',
                          style: TextStyle(
                              color: colors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0)),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_full_rounded,
                        size: 14, color: colors.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(child: _buildLyricsSurfaceBody(player)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsSurfaceBody(PlayerProvider player) {
    if (_lyricsLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_lyricsLines.isNotEmpty) {
      final focus = _currentLineIndex < 0 ? 0 : _currentLineIndex;
      var start = (focus - 2).clamp(0, _lyricsLines.length);
      var end = (start + 6).clamp(0, _lyricsLines.length);
      if (end - start < 6) start = (end - 6).clamp(0, end);
      final visible = _lyricsLines.sublist(start, end);
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Column(
          key: ValueKey<int>(focus),
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var offset = 0; offset < visible.length; offset++)
              GestureDetector(
                onTap: () => player
                    .seek(Duration(milliseconds: visible[offset].timestampMs)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    visible[offset].text.isEmpty ? '♪' : visible[offset].text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: start + offset == focus
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: start + offset == focus ? 17 : 13,
                      height: 1.2,
                      fontWeight: start + offset == focus
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final plainText = _lyricsResult?.plainText?.trim();
    if (plainText != null && plainText.isNotEmpty) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Text(
          plainText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            _lyricsResult?.instrumental == true
                ? AppLocale.tr('instrumental')
                : 'Bu parça için söz bulunamadı',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: player.currentSong == null
                ? null
                : () => _fetchLyrics(player.currentSong!),
            child: const Text('Yeniden dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSurface(PlayerProvider player) {
    final queue = player.queue;
    final cs = Theme.of(context).colorScheme;
    if (queue.isEmpty) {
      return Center(
        child: Text('Sıra boş',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    final current = player.currentIndex.clamp(0, queue.length - 1);
    var start = (current - 2).clamp(0, queue.length);
    var end = (start + 6).clamp(0, queue.length);
    if (end - start < 6) start = (end - 6).clamp(0, end);
    final indices = List<int>.generate(end - start, (i) => start + i);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
              child: Row(
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: cs.onSurface, size: 18),
                  const SizedBox(width: 8),
                  Text('${queue.length} parçalık sıra',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showQueue(context),
                    child: const Text('Tümünü aç'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: indices.length,
                itemBuilder: (context, offset) {
                  final index = indices[offset];
                  final song = queue[index];
                  final active = index == current;
                  return ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: song.albumArt == null || song.albumArt!.isEmpty
                          ? Container(
                              width: 38,
                              height: 38,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.music_note_rounded,
                                  size: 18, color: cs.onSurfaceVariant),
                            )
                          : Image.memory(song.albumArt!,
                              width: 38, height: 38, fit: BoxFit.cover),
                    ),
                    title: Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: active ? cs.primary : cs.onSurface,
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500)),
                    subtitle: Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11)),
                    trailing: active
                        ? Icon(Icons.equalizer_rounded,
                            size: 18, color: cs.primary)
                        : Text('${index + 1}',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 11)),
                    onTap: () => player.playFromQueue(queue, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleLineLyrics() {
    String line;
    bool hasTiming = false;

    if (_lyricsLines.isNotEmpty &&
        _currentLineIndex >= 0 &&
        _currentLineIndex < _lyricsLines.length) {
      line = _lyricsLines[_currentLineIndex].text;
      hasTiming = true;
    } else if (_lyricsLines.isNotEmpty) {
      line = _lyricsLines.first.text;
      hasTiming = true;
    } else if (_lyricsResult?.plainText != null) {
      final lines = _lyricsResult!.plainText!
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      line = lines.isNotEmpty ? lines.first : '';
    } else if (_lyricsResult?.instrumental == true) {
      line = AppLocale.tr('instrumental');
    } else {
      line = _lyricsLoading ? 'Sözler eşitleniyor…' : 'Sözler için dokun';
    }

    if (line.isEmpty) {
      line = '♪';
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LyricsScreen(
              lyricsDurationMs: _lyricsResult?.durationMs ?? 0,
            ),
          ),
        );
        if (!mounted) return;
        final song = context.read<PlayerProvider>().currentSong;
        if (song != null) await _loadLyricsOffset(song);
      },
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            if (_lyricsLoading)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.lyrics_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: SizedBox(
                      key: ValueKey(
                          'lyric_${_currentLineIndex}_${_lyricsLines.length}_$line'),
                      width: constraints.maxWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          line,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: hasTiming
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontSize: hasTiming ? 15 : 13,
                            fontWeight:
                                hasTiming ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Icon(Icons.open_in_full_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtFallback() {
    return const MelodiArtworkFallback(
      borderRadius: 0,
    );
  }

  void _showSongInfo(BuildContext context, SongModel song) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        title: Text(song.title,
            style: TextStyle(color: cs.onSurface, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(AppLocale.tr('artist_label'), song.artist),
            _infoRow(AppLocale.tr('album_label'), song.album),
            if (song.genre != null)
              _infoRow(AppLocale.tr('genre_label'), song.genre!),
            if (song.year != null)
              _infoRow(AppLocale.tr('year_label'), '${song.year}'),
            if (song.trackNumber != null)
              _infoRow(AppLocale.tr('track_label'), '${song.trackNumber}'),
            if (song.bitrate != null)
              _infoRow(AppLocale.tr('bitrate_label'), '${song.bitrate} kbps'),
            _infoRow(AppLocale.tr('duration_label'),
                song.duration.toFormattedString()),
            _infoRow(
                AppLocale.tr('file_label'),
                song.filePath.startsWith('youtube://')
                    ? 'YouTube Streaming'
                    : song.filePath.startsWith('http')
                        ? 'Online Streaming'
                        : song.filePath.split('/').last),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: cs.onSurface, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSong(BuildContext context, SongModel song) async {
    try {
      final result = await ShareService.instance.shareSong(song);
      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paylaşım bu aygıtta kullanılamıyor'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('share')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSleepTimer(BuildContext context, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    final durations = [5, 10, 15, 30, 45, 60, 90, 120];
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('sleep_timer'),
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...durations.map((minutes) {
              final label = minutes >= 60
                  ? '${minutes ~/ 60} ${AppLocale.tr('hr')} ${minutes % 60} ${AppLocale.tr('min')}'
                  : '$minutes ${AppLocale.tr('min')}';
              final isSelected = minutes == player.sleepTimerMinutes;
              return ListTile(
                leading: Icon(Icons.timer_outlined,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    size: 20),
                title: Text(label,
                    style: TextStyle(
                        color: isSelected ? cs.primary : cs.onSurface,
                        fontSize: 14)),
                trailing: isSelected
                    ? Icon(Icons.check, color: cs.primary, size: 18)
                    : null,
                onTap: () {
                  final timerDuration = Duration(minutes: minutes);
                  player.handler.setSleepTimer(timerDuration);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${AppLocale.tr('sleep_timer')}: $label'),
                    ),
                  );
                },
              );
            }),
            ListTile(
              leading: Icon(Icons.close, color: cs.error, size: 20),
              title: Text(AppLocale.tr('off'),
                  style: TextStyle(color: cs.error, fontSize: 14)),
              onTap: () {
                player.handler.setSleepTimer(Duration.zero);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocale.tr('sleep_timer_canceled')),
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
    final cs = Theme.of(context).colorScheme;
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.playlist_add, color: cs.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('add_to_playlist'),
                  style: TextStyle(color: cs.onSurface, fontSize: 14)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddToPlaylist(context, song);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('song_info'),
                  style: TextStyle(color: cs.onSurface, fontSize: 14)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSongInfo(context, song);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: cs.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('share'),
                  style: TextStyle(color: cs.onSurface, fontSize: 14)),
              subtitle: Text(AppLocale.tr('share_file'),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _shareSong(this.context, song);
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.timer, color: cs.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('sleep_timer'),
                  style: TextStyle(color: cs.onSurface, fontSize: 14)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSleepTimer(context, player);
              },
            ),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: cs.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('crossfade'),
                  style: TextStyle(color: cs.onSurface, fontSize: 14)),
              onTap: () {
                Navigator.pop(sheetContext);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 3,
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const CrossfadeSlider(),
                        ],
                      ),
                    ),
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
          color: Colors.white .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              '${currentSpeed.toStringAsFixed(2)}x'
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), ''),
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
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
          color: showSlider
              ? accentColor .withValues(alpha: 0.2)
              : Colors.white .withValues(alpha: 0.1),
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
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
