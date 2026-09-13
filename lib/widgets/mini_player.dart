import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/spotify_colors.dart';

/// Spotify mini kart: #181818 zemin, yesil dairesel play, ince yesil progress.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});
  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  String? _dismissedId;
  void _openPlayer(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        if (song.id == _dismissedId && !player.isPlaying) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Dismissible(
          key: ValueKey('mini-player-${song.id}'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) {
            setState(() => _dismissedId = song.id);
            player.handler.stop();
          },
          child: Material(
            color: SpotifyColors.darkSurface,
            child: InkWell(
              onTap: () => _openPlayer(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: (player.duration.inMilliseconds <= 0)
                        ? 0
                        : (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: SpotifyColors.midDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        SpotifyColors.green),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: song.albumArt != null && song.albumArt!.isNotEmpty
                                ? Image.memory(song.albumArt!, fit: BoxFit.cover, gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => _fallback(scheme))
                                : _fallback(scheme),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: SpotifyColors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              Text(song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: SpotifyColors.silver,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400)),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: SpotifyColors.greenPlayCircle,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black),
                            onPressed: player.playPause,
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.skip_next_rounded,
                                color: SpotifyColors.silver),
                            onPressed: player.skipToNext),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(ColorScheme s) => Container(
        color: SpotifyColors.midDark,
        child: const Icon(Icons.music_note_rounded,
            size: 20, color: SpotifyColors.silver),
      );
}
