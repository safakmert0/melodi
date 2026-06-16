import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../core/extensions/duration_ext.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import 'image_with_fallback.dart';
import 'queue_sheet.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onPlayNext;
  final VoidCallback? onViewAlbum;
  final VoidCallback? onViewArtist;
  final Widget? trailing;
  final bool showArtwork;
  final bool showFavorite;
  final double artworkSize;

  const SongTile({
    super.key,
    required this.song,
    this.isPlaying = false,
    this.onTap,
    this.onFavorite,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onViewAlbum,
    this.onViewArtist,
    this.trailing,
    this.showArtwork = true,
    this.showFavorite = true,
    this.artworkSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: showArtwork
          ? Stack(
              children: [
                ArtworkImage(
                  imageBytes: song.albumArt,
                  size: artworkSize,
                  borderRadius: 6,
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.equalizer_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            )
          : null,
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (song.bitrate != null) ...[
            Text(
              ' · ',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            ),
            Text(
              '${song.bitrate} kbps',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showFavorite)
                IconButton(
                  icon: Icon(
                    song.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: song.isFavorite
                        ? AppTheme.favoriteColor
                        : AppTheme.textTertiary,
                    size: 20,
                  ),
                  onPressed: onFavorite ??
                      () => context
                          .read<LibraryProvider>()
                          .toggleFavorite(song),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz,
                    color: AppTheme.textSecondary, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'queue':
                      (onAddToQueue ??
                          () => context
                              .read<PlayerProvider>()
                              .addToQueue(song))
                          .call();
                      break;
                    case 'playNext':
                      (onPlayNext ??
                          () => context
                              .read<PlayerProvider>()
                              .insertNext(song))
                          .call();
                      break;
                    case 'playlist':
                      (onAddToPlaylist ??
                          () => _showAddToPlaylistSheet(context))
                          .call();
                      break;
                    case 'album':
                      onViewAlbum?.call();
                      break;
                    case 'artist':
                      onViewArtist?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'queue',
                    child: ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(AppLocale.tr('add_to_queue')),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playNext',
                    child: ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(AppLocale.tr('play_next')),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playlist',
                    child: ListTile(
                      leading: const Icon(Icons.playlist_add),
                      title: Text(AppLocale.tr('add_to_playlist')),
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'album',
                    child: ListTile(
                      leading: const Icon(Icons.album),
                      title: Text(AppLocale.tr('view_album')),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'artist',
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(AppLocale.tr('view_artist')),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
      minLeadingWidth: artworkSize + 8,
    ).animate().fadeIn(duration: 300.ms);
  }

  void _showAddToPlaylistSheet(BuildContext context) {
    final playlists = context.read<PlaylistProvider>().playlists;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToPlaylistSheet(
        song: song,
        playlists: playlists,
      ),
    );
  }
}
