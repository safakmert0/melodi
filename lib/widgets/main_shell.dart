import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';

/// Main shell widget that holds the overall app structure
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final downloadProvider = context.watch<DownloadProvider>();

    return Scaffold(
      body: Column(
        children: [
          // Home screen (default)
          const Expanded(child: HomeScreen()),

          // Divider
          const Divider(height: 1, color: Colors.grey),

          // Bottom control bar
          _BuildControlBar(
            isPlaying: player.isPlaying,
            currentSong: player.currentSong,
            onPlayPause: () {
              if (player.isPlaying) {
                player.pause();
              } else {
                player.play();
              }
            },
            onSkipNext: () => player.skipToNext(),
            onSkipPrevious: () => player.skipToPrevious(),
            onDownload: () {
              // Navigate to downloads
            },
          ),
        ],
      ),
    );
  }
}

/// Build control bar at the bottom of the main shell
class _BuildControlBar extends StatelessWidget {
  final bool isPlaying;
  final SongModel? currentSong;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onDownload;

  const _BuildControlBar({
    required this.isPlaying,
    required this.currentSong,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onDownload,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      color: cardColor,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Skip previous
          _NavButton(
            icon: Icons.skip_previous,
            onTap: onSkipPrevious,
            isDisabled: currentSong == null,
          ),

          // Play/pause
          _PlayPauseButton(
            isPlaying: isPlaying,
            onTap: onPlayPause,
          ),

          // Skip next
          _NavButton(
            icon: Icons.skip_next,
            onTap: onSkipNext,
            isDisabled: currentSong == null,
          ),
        ],
      ),
    );
  }
}

/// Navigation button for control bar
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDisabled;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.isDisabled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled ? Colors.grey : Colors.green;
    return IconButton(
      icon: Icon(icon, color: color, size: 28),
      onPressed: isDisabled ? null : onTap,
      tooltip: isDisabled ? 'Şarkı yok' : null,
    );
  }
}

/// Play/pause button for control bar
class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPlaying ? Colors.red : Colors.green;
    return IconButton(
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: color,
        size: 28,
      ),
      onTap: onTap,
    );
  }
}