import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/share_service.dart';
import '../services/color_extractor.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import 'queue_screen.dart';
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
import '../services/playback_service.dart';
import '../widgets/seek_bar.dart';
import '../widgets/image_with_fallback.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/lyrics_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/crossfade_slider.dart';

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
  Color _dynamicColor = MelodiTheme.primaryGreen;

  LyricsResult? _lyricsResult;
  List<LrcLine> _lyricsLines = [];
  int _currentLineIndex = -1;
  final ScrollController _lyricsScrollController = ScrollController();
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
    _lyricsScrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      final palette = await ColorExtractor.extractColors(bytes);
      if (mounted) {
        setState(() => _dynamicColor = palette.dominant);
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
            backgroundColor: const Color(0xFF131313),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Color(0xFFe5e2e1)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                AppLocale.tr('now_playing'),
                style: const TextStyle(
                  color: Color(0xFFe5e2e1),
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
                  const Icon(Icons.music_note_rounded, size: 80, color: Color(0xFFbccbb9)),
                  const SizedBox(height: 24),
                  Text(
                    AppLocale.tr('no_song_playing'),
                    style: const TextStyle(color: Color(0xFFe5e2e1), fontSize: 18),
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
          backgroundColor: Colors.transparent,
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
                    filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                ),
              ] else
                Positioned.fill(child: Container(color: const Color(0xFF131313))),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        Color(0xFF53e076),
                        Color(0xFF5203d5),
                      ],
                    ),
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ),
              // Top bar
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.expand_more_rounded, size: 30, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
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
                  children: [
                    const Spacer(flex: 2),
                    // Album Art with green glow
                    Center(
                      child: SizedBox(
                        width: 340,
                        height: 340,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (hasArt)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF53e076).withOpacity(0.2),
                                        blurRadius: 80,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
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
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                    // Song Title + Artist (Stitch style: centered, title 28px bold, artist in green)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFe5e2e1),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF53e076),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar (4px, green active)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: MelodiSeekBar(
                        position: player.position,
                        duration: player.duration,
                        bufferedPosition: player.handler.bufferedPosition,
                        onSeek: player.seek,
                        activeColor: const Color(0xFF53e076),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Main controls (shuffle, prev, play/pause 72px green glow, next, repeat)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: player.isShuffled ? const Color(0xFF53e076) : Colors.white54,
                            size: 24,
                          ),
                          onPressed: player.toggleShuffle,
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                          onPressed: player.skipToPrevious,
                        ),
                        const SizedBox(width: 12),
                        // Play/Pause with green glow
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF53e076),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF53e076).withOpacity(0.5),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFF131313),
                              size: 40,
                            ),
                            onPressed: player.playPause,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                          onPressed: player.skipToNext,
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: Icon(
                            Icons.repeat_rounded,
                            color: player.repeatMode != LoopStyle.off ? const Color(0xFF53e076) : Colors.white54,
                            size: 24,
                          ),
                          onPressed: player.cycleRepeatMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Supplementary actions row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SpeedButton(
                              player: player, speedOptions: _speedOptions, accentColor: const Color(0xFF53e076)),
                          const SizedBox(width: 8),
                          Consumer<LibraryProvider>(
                            builder: (context, lib, _) {
                              final isFav = lib.favorites.any((s) => s.id == song.id);
                              return IconButton(
                                icon: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? const Color(0xFF53e076) : Colors.white54,
                                  size: 22,
                                ),
                                onPressed: () => lib.toggleFavorite(song),
                              );
                            },
                          ),
                          Consumer<DownloadProvider>(
                            builder: (context, dl, _) {
                              final song = context.read<PlayerProvider>().currentSong;
                              final status = song != null
                                  ? dl.getStatusForSong(song.title, song.artist)
                                  : null;
                              final isDownloaded = status == DownloadState.completed;
                              final isDownloading = status == DownloadState.downloading || status == DownloadState.pending;
                              return IconButton(
                                icon: Icon(
                                  isDownloaded
                                      ? Icons.download_done_rounded
                                      : isDownloading
                                          ? Icons.hourglass_top_rounded
                                          : Icons.download_outlined,
                                  color: isDownloaded ? const Color(0xFF53e076) : Colors.white54,
                                  size: 22,
                                ),
                                onPressed: isDownloaded || isDownloading
                                    ? null
                                    : () {
                                        if (song != null) {
                                          dl.enqueueTrack(
                                            spotifyTrackId: 'youtube',
                                            title: song.title,
                                            artist: song.artist,
                                            album: song.album,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${song.title} indiriliyor...'),
                                              backgroundColor: const Color(0xFF53e076),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music_rounded, color: Colors.white54, size: 22),
                            onPressed: () => _showQueue(context),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.dark_mode_rounded,
                              color: Colors.white54,
                              size: 22,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: MelodiTheme.containerLow,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (_) => const SleepTimerSheet(),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _VolumeBoostButton(
                            player: player,
                            showSlider: _showVolumeSlider,
                            onToggle: () => setState(() => _showVolumeSlider = !_showVolumeSlider),
                            accentColor: const Color(0xFF53e076),
                          ),
                        ],
                      ),
                    ),
                    if (_showVolumeSlider)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_down_rounded, color: Colors.white54, size: 16),
                            Expanded(
                              child: Slider(
                                value: player.volumeBoost.clamp(0.5, 2.0),
                                min: 0.5,
                                max: 2.0,
                                onChanged: (v) => player.setVolume(v),
                                activeColor: const Color(0xFF53e076),
                                inactiveColor: Colors.white24,
                              ),
                            ),
                            const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
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

  Widget _buildSingleLineLyrics() {
    String line;
    bool hasTiming = false;

    if (_lyricsLines.isNotEmpty && _currentLineIndex >= 0 && _currentLineIndex < _lyricsLines.length) {
      line = _lyricsLines[_currentLineIndex].text;
      hasTiming = true;
    } else if (_lyricsLines.isNotEmpty) {
      line = _lyricsLines.first.text;
      hasTiming = true;
    } else if (_lyricsResult?.plainText != null) {
      final lines = _lyricsResult!.plainText!.split('\n').where((l) => l.trim().isNotEmpty).toList();
      line = lines.isNotEmpty ? lines.first : '';
    } else if (_lyricsResult?.instrumental == true) {
      line = AppLocale.tr('instrumental');
    } else {
      return const SizedBox(height: 40, child: Center(
        child: Text('♪', style: TextStyle(color: Colors.white24, fontSize: 20)),
      ));
    }

    if (line.isEmpty) {
      return const SizedBox(height: 40, child: Center(
        child: Text('♪', style: TextStyle(color: Colors.white24, fontSize: 20)),
      ));
    }

    final p = context.read<PlayerProvider>();
    return GestureDetector(
      onTap: () {
        if (_lyricsLines.isNotEmpty && _currentLineIndex >= 0) {
          p.seek(Duration(milliseconds: _lyricsLines[_currentLineIndex].timestampMs));
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Padding(
          key: ValueKey('lyric_${_currentLineIndex}_${_lyricsLines.length}'),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
          child: Text(
            line,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasTiming ? Colors.white : Colors.white54,
              fontSize: hasTiming ? 17 : 14,
              fontWeight: hasTiming ? FontWeight.w600 : FontWeight.w400,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
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
    if (_lyricsLines.isEmpty) {
      return Center(
        child: Text(
          '♪',
          style: TextStyle(color: Colors.white38, fontSize: 36),
        ),
      );
    }

    final currentLine = _currentLineIndex >= 0 && _currentLineIndex < _lyricsLines.length
        ? _lyricsLines[_currentLineIndex]
        : null;
    final prevLine = _currentLineIndex > 0
        ? _lyricsLines[_currentLineIndex - 1]
        : null;
    final nextLine = _currentLineIndex >= 0 && _currentLineIndex < _lyricsLines.length - 1
        ? _lyricsLines[_currentLineIndex + 1]
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prevLine != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
            child: Text(
              prevLine.text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15,
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            if (currentLine != null) {
              final player = context.read<PlayerProvider>();
              player.seek(Duration(milliseconds: currentLine.timestampMs));
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Padding(
              key: ValueKey(currentLine?.timestampMs ?? 0),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                currentLine?.text ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (nextLine != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
            child: Text(
              nextLine.text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15,
              ),
            ),
          ),
      ],
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF201f1f),
            Color(0xFF2a2a2a),
          ],
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        size: 80,
        color: Color(0xFFbccbb9),
      ),
    );
  }

  void _showSongInfo(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(song.title,
            style: TextStyle(color: MelodiTheme.onSurface)),
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
                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
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
                    color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: MelodiTheme.onSurface, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSong(BuildContext context, SongModel song) async {
    try {
      await ShareService.instance.shareSong(song);
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('share')),
            backgroundColor: MelodiTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showSleepTimer(BuildContext context, PlayerProvider player) {
    final durations = [
      5, 10, 15, 30, 45, 60, 90, 120
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('sleep_timer'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...durations.map((minutes) {
              final label = minutes >= 60
                  ? '${minutes ~/ 60} ${AppLocale.tr('hr')} ${minutes % 60} ${AppLocale.tr('min')}'
                  : '$minutes ${AppLocale.tr('min')}';
              final isSelected = minutes == player.sleepTimerMinutes;
              return ListTile(
                leading: Icon(Icons.timer_outlined, color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant),
                title: Text(label,
                    style: TextStyle(color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.onSurface)),
                trailing: isSelected ? Icon(Icons.check, color: MelodiTheme.primaryGreen, size: 20) : null,
                onTap: () {
                  final timerDuration = Duration(minutes: minutes);
                  player.handler.setSleepTimer(timerDuration);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${AppLocale.tr('sleep_timer')}: $label'),
                      backgroundColor: MelodiTheme.primaryGreen,
                    ),
                  );
                },
              );
            }),
            ListTile(
              leading: Icon(Icons.close, color: MelodiTheme.errorRed),
              title: Text(AppLocale.tr('off'),
                  style: TextStyle(color: MelodiTheme.errorRed)),
              onTap: () {
                player.handler.setSleepTimer(Duration.zero);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocale.tr('sleep_timer_canceled')),
                    backgroundColor: MelodiTheme.primaryGreen,
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
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.playlist_add, color: MelodiTheme.onSurfaceVariant),
              title: Text(AppLocale.tr('add_to_playlist'),
                  style: TextStyle(color: MelodiTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song!);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: MelodiTheme.onSurfaceVariant),
              title: Text(AppLocale.tr('song_info'),
                  style: TextStyle(color: MelodiTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showSongInfo(context, song!);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: MelodiTheme.onSurfaceVariant),
              title: Text(AppLocale.tr('share'),
                  style: TextStyle(color: MelodiTheme.onSurface)),
              subtitle: Text(AppLocale.tr('share_file'),
                  style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _shareSong(context, song!);
              },
            ),
            ListTile(
              leading: Icon(Icons.timer, color: MelodiTheme.onSurfaceVariant),
              title: Text(AppLocale.tr('sleep_timer'),
                  style: TextStyle(color: MelodiTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showSleepTimer(context, player);
              },
            ),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: MelodiTheme.onSurfaceVariant),
              title: Text(AppLocale.tr('crossfade'),
                  style: TextStyle(color: MelodiTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: MelodiTheme.containerLow,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: MelodiTheme.outlineVariant,
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
          color: Colors.white.withOpacity(0.1),
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
          color: showSlider ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.1),
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
