import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../services/metadata_service.dart';
import '../services/lyrics_service.dart';

class LyricsSheet extends StatefulWidget {
  const LyricsSheet({super.key});

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  String? _lyrics;
  String? _syncedLyrics;
  List<LrcLine> _lyricsLines = [];
  int _currentLineIndex = -1;
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
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
      if (_lyricsLines.isNotEmpty) {
        final player = context.read<PlayerProvider>();
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
    final offset = (_currentLineIndex * 56.0) - 100;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _fetchLyrics() async {
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    String? lyricsText;
    String? syncedText;

    final cachedLyrics = await MetadataService.getLyrics(song.id);
    final cachedSynced = await MetadataService.getSyncedLyrics(song.id);

    lyricsText = cachedLyrics;
    syncedText = cachedSynced;

    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      lyricsText ??= song.lyrics;
      final parsed = LrcParser.parse(song.lyrics!);
      if (parsed.isNotEmpty && syncedText == null) {
        syncedText = song.lyrics;
      }
    }

    if (mounted) {
      setState(() {
        _lyrics = lyricsText;
        _syncedLyrics = syncedText;
        _loading = false;
        if (syncedText != null) {
          _lyricsLines = LrcParser.parse(syncedText);
          _lyricsLines.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
          Text(
            AppLocale.tr('lyrics'),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppTheme.divider, height: 1),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lyricsLines.isNotEmpty) {
      return _buildSyncedLyrics();
    }

    if (_lyrics != null && _lyrics!.isNotEmpty) {
      return _buildPlainLyrics();
    }

    return Center(
      child: Text(
        AppLocale.tr('no_lyrics'),
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSyncedLyrics() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 24),
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
                  ? AppTheme.primaryColor
                  : isPast
                      ? AppTheme.textSecondary
                      : AppTheme.textTertiary,
              fontSize: isCurrent ? 18 : 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
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

  Widget _buildPlainLyrics() {
    final lines = _lyrics!.split('\n');
    return ListView.builder(
      itemCount: lines.length,
      padding: const EdgeInsets.symmetric(vertical: 24),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
          child: Text(
            lines[index].trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }
}
