import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../core/extensions/duration_ext.dart';
import '../services/audio_handler.dart';
import '../services/database_service.dart';
import '../models/song_model.dart';

class LyricsScreen extends StatefulWidget {
  final int lyricsDurationMs;

  const LyricsScreen({super.key, this.lyricsDurationMs = 0});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  List<LrcLine> _lyricsLines = [];
  int _currentLineIndex = -1;
  final PageController _pageController = PageController(viewportFraction: 0.22);
  Timer? _timer;
  String? _activeSongId;
  int _manualOffsetMs = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      final song = player.currentSong;
      if (song == null) return;
      if (_activeSongId != song.id) {
        _prepareSong(song);
      }
      if (_lyricsLines.isNotEmpty) {
        _updateCurrentLine(player);
      }
    });
  }

  void _prepareSong(SongModel song) {
    _activeSongId = song.id;
    _currentLineIndex = -1;
    final text = song.lyrics;
    if (text == null || text.trim().isEmpty) {
      _lyricsLines = [];
    } else {
      final parsed = LrcParser.parse(text);
      _lyricsLines =
          parsed.isNotEmpty ? parsed : <LrcLine>[LrcLine(0, text.trim())];
    }
    DatabaseService.instance.getSetting('lyrics_offset_${song.id}').then((raw) {
      if (!mounted || _activeSongId != song.id) return;
      _manualOffsetMs = int.tryParse(raw ?? '') ?? 0;
      _updateCurrentLine(context.read<PlayerProvider>());
    });
    if (mounted) setState(() {});
  }

  void _updateCurrentLine(PlayerProvider player) {
    final index = LyricsTiming.findLineIndexAtPlayback(
      lines: _lyricsLines,
      playbackPositionMs: player.position.inMilliseconds,
      manualOffsetMs: _manualOffsetMs,
      playbackDurationMs: player.duration.inMilliseconds,
      lyricsDurationMs: widget.lyricsDurationMs,
    );
    if (index == _currentLineIndex) return;
    _currentLineIndex = index;
    if (mounted) setState(() {});
    _centerCurrentLine();
  }

  void _centerCurrentLine() {
    if (_currentLineIndex < 0 || !_pageController.hasClients) return;
    _pageController.animateToPage(
      _currentLineIndex,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _adjustOffset(int deltaMs) async {
    final song = context.read<PlayerProvider>().currentSong;
    if (song == null) return;
    setState(() {
      _manualOffsetMs = (_manualOffsetMs + deltaMs).clamp(-5000, 5000);
    });
    await DatabaseService.instance
        .setSetting('lyrics_offset_${song.id}', _manualOffsetMs.toString());
    if (mounted) _updateCurrentLine(context.read<PlayerProvider>());
  }

  double _fontSizeForLine(String text, {required bool isActive}) {
    final length = text.trim().length;
    if (length > 110) return isActive ? 19 : 17;
    if (length > 78) return isActive ? 21 : 18;
    if (length > 52) return isActive ? 23 : 20;
    return isActive ? 27 : 23;
  }

  void _seekToLine(LrcLine line) {
    final player = context.read<PlayerProvider>();
    final position = LyricsTiming.playbackPositionMs(
      lyricPositionMs: line.timestampMs,
      manualOffsetMs: _manualOffsetMs,
      playbackDurationMs: player.duration.inMilliseconds,
      lyricsDurationMs: widget.lyricsDurationMs,
    );
    player.seek(Duration(milliseconds: position));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final song = player.currentSong;
          if (song == null) return const SizedBox.shrink();

          if (_lyricsLines.isEmpty && song.lyrics != null) {
            final parsed = LrcParser.parse(song.lyrics!);
            if (parsed.isNotEmpty) {
              _lyricsLines = parsed;
            } else {
              _lyricsLines = [LrcLine(0, song.lyrics!)];
            }
          }

          return Container(
            color: Theme.of(context).colorScheme.surface,
                    child: Column(
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 24),
                              color: Theme.of(context).colorScheme.onSurface,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    AppLocale.tr('lyrics'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (song.albumArt != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  song.albumArt!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _lyricsLines.isEmpty
                          ? Center(
                              child: Text(
                                AppLocale.tr('no_lyrics_available'),
                                style: TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : PageView.builder(
                              controller: _pageController,
                              scrollDirection: Axis.vertical,
                              physics: const BouncingScrollPhysics(),
                              padEnds: true,
                              itemCount: _lyricsLines.length,
                              itemBuilder: (context, index) {
                                final line = _lyricsLines[index];
                                final isActive = index == _currentLineIndex;
                                return InkWell(
                                  onTap: () => _seekToLine(line),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 6,
                                    ),
                                    child: AnimatedScale(
                                      scale: isActive ? 1.0 : 0.96,
                                      alignment: Alignment.centerLeft,
                                      duration:
                                          const Duration(milliseconds: 280),
                                      child: AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 280),
                                        style: TextStyle(
                                          fontFamily: AppConstants.fontFamily,
                                          fontSize: _fontSizeForLine(
                                            line.text,
                                            isActive: isActive,
                                          ),
                                          fontWeight: FontWeight.w800,
                                          height: 1.12,
                                          letterSpacing: -0.55,
                                          color: isActive
                                              ? MelodiTheme.onSurface
                                              : MelodiTheme.onSurface
                                                  .withOpacity(0.22),
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            line.text,
                                            maxLines: 4,
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                            textAlign: TextAlign.left,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                            top: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: '-0.5 sn',
                                onPressed: () => _adjustOffset(-500),
                                icon: const Icon(Icons.fast_rewind_rounded),
                                color: MelodiTheme.onSurfaceVariant,
                              ),
                              TextButton(
                                onPressed: () =>
                                    _adjustOffset(-_manualOffsetMs),
                  child: Text(
                                   '${(_manualOffsetMs / 1000).toStringAsFixed(1)} sn',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '+0.5 sn',
                                onPressed: () => _adjustOffset(500),
                                icon: const Icon(Icons.fast_forward_rounded),
                                color: MelodiTheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                player.position.toShortString(),
                                style: TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: MelodiTheme.onSurface,
                                    inactiveTrackColor:
                                        MelodiTheme.surfaceBright,
                                    thumbColor: MelodiTheme.onSurface,
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 4),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 10),
                                  ),
                                  child: Slider(
                                    value: player.duration.inMilliseconds > 0
                                        ? player.position.inMilliseconds /
                                            player.duration.inMilliseconds
                                        : 0.0,
                                    onChanged: (value) {
                                      final pos = Duration(
                                        milliseconds: (value *
                                                player.duration.inMilliseconds)
                                            .round(),
                                      );
                                      player.seek(pos);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                player.duration.toShortString(),
                                style: TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color: player.isShuffled
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                                iconSize: 22,
                                onPressed: player.toggleShuffle,
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded),
                                color: Theme.of(context).colorScheme.onSurface,
                                iconSize: 28,
                                onPressed: player.skipToPrevious,
                              ),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    player.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                  ),
                                  iconSize: 22,
                                  onPressed: player.playPause,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded),
                                color: Theme.of(context).colorScheme.onSurface,
                                iconSize: 28,
                                onPressed: player.skipToNext,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.repeat,
                                  color: player.repeatMode != LoopStyle.off
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                                iconSize: 22,
                                onPressed: player.cycleRepeatMode,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
        },
      ),
    );
  }
}
