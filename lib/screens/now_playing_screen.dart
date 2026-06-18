import 'dart:async';
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

  LyricsResult? _lyricsResult;
  List<LrcLine> _lyricsLines = [];
  int _currentLineIndex = -1;
  final ScrollController _lyricsScrollController = ScrollController();
  Timer? _lyricsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _startLyricsTimer();
  }

  @override
  void dispose() {
    _lyricsTimer?.cancel();
    _lyricsScrollController.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    super.dispose();
  }

  void _startLyricsTimer() {
    _lyricsTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      if (_lyricsLines.isNotEmpty) {
        _updateCurrentLine(player.position.inMilliseconds);
      }
    });
  }

  void _updateCurrentLine(int positionMs) {
    int idx = -1;
    for (int i = 0; i < _lyricsLines.length; i++) {
      if (_lyricsLines[i].timestampMs <= positionMs) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _currentLineIndex) {
      _currentLineIndex = idx;
      if (mounted) setState(() {});
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (_currentLineIndex < 0 || !_lyricsScrollController.hasClients) return;
    final offset = (_currentLineIndex * 56.0) - (MediaQuery.of(context).size.height * 0.15);
    _lyricsScrollController.animateTo(
      offset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
    _lyricsResult = null;
    _lyricsLines = [];
    _currentLineIndex = -1;
    _extractColor(song.albumArt);
    if (song.lyrics == null || song.lyrics!.isEmpty) {
      Future.microtask(() => _fetchLyrics(song));
    } else {
      final text = song.lyrics!;
      final parsed = LrcParser.parse(text);
      if (parsed.isNotEmpty) {
        _lyricsLines = parsed;
        _lyricsResult = LyricsResult(syncedLrc: text);
      } else {
        _lyricsResult = LyricsResult(plainText: text);
      }
    }
    if (song.albumArt == null) {
      Future.microtask(() => _fetchArtwork(song));
    }
  }

  Future<void> _fetchLyrics(SongModel song) async {
    final result = await LyricsService.fetchLyrics(
      artist: song.artist,
      track: song.title,
      album: song.album,
      durationMs: song.duration.inMilliseconds,
      filePath: song.filePath,
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
      setState(() {});
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

        return GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
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
                    // Album Art - centered with glow (fixed size)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width > 400 ? 56 : 40,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _dynamicColor.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
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
                    // Lyrics preview (2 lines, always visible when available)
                    if (_lyricsLines.isNotEmpty || _lyricsResult?.plainText != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: GestureDetector(
                          onTap: _showLyrics
                              ? null
                              : () {
                                  if (song.lyrics != null && song.lyrics!.isNotEmpty) {
                                    setState(() => _showLyrics = true);
                                  }
                                },
                          child: _buildLyricsPreview(),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    // Lyrics full view (always takes space when toggled)
                    Expanded(
                      child: _showLyrics
                          ? _buildLyricsView(player)
                          : const SizedBox.shrink(),
                    ),
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
                    // Mode indicators
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (player.isShuffled)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                AppLocale.tr('shuffled'),
                                style: TextStyle(
                                  color: _dynamicColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (player.repeatMode != LoopStyle.off)
                            Text(
                              player.repeatMode == LoopStyle.all
                                  ? AppLocale.tr('repeat_all')
                                  : AppLocale.tr('repeat_one'),
                              style: TextStyle(
                                color: _dynamicColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
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
        ),
      );
      },
    );
  }

  Widget _buildLyricsPreview() {
    final previewLines = <String>[];
    if (_lyricsLines.isNotEmpty) {
      final start = _currentLineIndex > 0 ? _currentLineIndex - 1 : 0;
      for (int i = start; i < _lyricsLines.length && previewLines.length < 2; i++) {
        previewLines.add(_lyricsLines[i].text);
      }
    } else if (_lyricsResult?.plainText != null) {
      final lines = _lyricsResult!.plainText!.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (int i = 0; i < lines.length && previewLines.length < 2; i++) {
        previewLines.add(lines[i].trim());
      }
    }
    if (previewLines.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: previewLines.map((line) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          line,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildLyricsView(PlayerProvider player) {
    final state = _lyricsViewState();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: state,
    );
  }

  Widget _lyricsViewState() {
    if (_lyricsResult == null && _lyricsLines.isEmpty) {
      return Center(
        child: Text(
          '♪',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 36,
          ),
        ),
      );
    }

    if (_lyricsResult?.instrumental == true) {
      return Center(
        child: Text(
          AppLocale.tr('instrumental'),
          style: TextStyle(
            color: Colors.white54,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (_lyricsLines.isNotEmpty) {
      return _buildSyncedLyrics();
    }

    if (_lyricsResult?.plainText != null) {
      return _buildPlainLyrics(_lyricsResult!.plainText!);
    }

    return Center(
      child: Text(
        AppLocale.tr('no_lyrics'),
        style: TextStyle(
          color: Colors.white38,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSyncedLyrics() {
    return ListView.builder(
      controller: _lyricsScrollController,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * 0.15,
        bottom: MediaQuery.of(context).size.height * 0.15,
      ),
      itemCount: _lyricsLines.length,
      itemBuilder: (context, index) {
        final line = _lyricsLines[index];
        final isCurrent = index == _currentLineIndex;
        final isPast = index < _currentLineIndex;

        return GestureDetector(
          onTap: () {
            final player = context.read<PlayerProvider>();
            player.seek(Duration(milliseconds: line.timestampMs));
          },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isCurrent
                  ? Colors.white
                  : isPast
                      ? Colors.white54
                      : Colors.white24,
              fontSize: isCurrent ? 18 : 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainLyrics(String text) {
    final lines = text.split('\n');
    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
          child: Text(
            lines[index].trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        );
      },
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
              final label = minutes >= 60
                  ? '${minutes ~/ 60} ${AppLocale.tr('hr')} ${minutes % 60} ${AppLocale.tr('min')}'
                  : '$minutes ${AppLocale.tr('min')}';
              final isSelected = minutes == player.sleepTimerMinutes;
              return ListTile(
                leading: Icon(Icons.timer_outlined, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
                title: Text(label,
                    style: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary)),
                trailing: isSelected ? Icon(Icons.check, color: AppTheme.primaryColor, size: 20) : null,
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
