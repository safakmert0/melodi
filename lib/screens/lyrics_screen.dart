import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../widgets/seek_bar.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  List<LrcLine> _lyricsLines = [];
  int _currentLineIndex = -1;
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
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
    if (_currentLineIndex < 0 || !_scrollController.hasClients) return;
    final offset = (_currentLineIndex * 56.0) - (MediaQuery.of(context).size.height * 0.35);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
              _lyricsLines = [LrcLine(timestampMs: 0, text: song.lyrics!)];
            }
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D2318),
                  MelodiTheme.background,
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Column(
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                              color: MelodiTheme.onSurface,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    AppLocale.tr('lyrics'),
                                    style: MelodiTheme.label(size: 10, letterSpacing: 1.5),
                                  ),
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppConstants.fontFamily,
                                      color: MelodiTheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (song.albumArt != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
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
                                style: const TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                vertical: MediaQuery.of(context).size.height * 0.3,
                                horizontal: 24,
                              ),
                              itemCount: _lyricsLines.length,
                              itemBuilder: (context, index) {
                                final line = _lyricsLines[index];
                                final isActive = index == _currentLineIndex;
                                return AnimatedScale(
                                  scale: isActive ? 1.05 : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: TextStyle(
                                      fontFamily: AppConstants.fontFamily,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      letterSpacing: -0.8,
                                      color: isActive
                                          ? MelodiTheme.onSurface
                                          : MelodiTheme.onSurface.withValues(alpha: 0.2),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(line.text),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            MelodiTheme.background.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                player.position.formatMmSs,
                                style: const TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: MelodiTheme.onSurface,
                                    inactiveTrackColor: MelodiTheme.surfaceBright,
                                    thumbColor: MelodiTheme.onSurface,
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                  ),
                                  child: Slider(
                                    value: player.duration.inMilliseconds > 0
                                        ? player.position.inMilliseconds / player.duration.inMilliseconds
                                        : 0.0,
                                    onChanged: (value) {
                                      final pos = Duration(
                                        milliseconds: (value * player.duration.inMilliseconds).round(),
                                      );
                                      player.seek(pos);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                player.duration.formatMmSs,
                                style: const TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  color: MelodiTheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  player.shuffleMode ? Icons.shuffle : Icons.shuffle,
                                  color: player.shuffleMode ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant,
                                ),
                                iconSize: 28,
                                onPressed: player.toggleShuffle,
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded),
                                color: MelodiTheme.onSurface,
                                iconSize: 36,
                                onPressed: player.skipToPrevious,
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MelodiTheme.surfaceBright,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: MelodiTheme.background,
                                  ),
                                  iconSize: 28,
                                  onPressed: player.playPause,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded),
                                color: MelodiTheme.onSurface,
                                iconSize: 36,
                                onPressed: player.skipToNext,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.repeat,
                                  color: player.loopMode != LoopMode.off
                                      ? MelodiTheme.primaryGreen
                                      : MelodiTheme.onSurfaceVariant,
                                ),
                                iconSize: 28,
                                onPressed: player.toggleLoopMode,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
