import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../core/constants.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../services/download_manager.dart';
import '../services/share_service.dart';
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
  final VoidCallback? onDownload;
  final Widget? trailing;
  final bool showArtwork;
  final bool showFavorite;
  final double artworkSize;
  final Widget? wrongMatchButton;
  final double? confidence;

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
    this.onDownload,
    this.trailing,
    this.showArtwork = true,
    this.showFavorite = true,
    this.artworkSize = 48,
    this.wrongMatchButton,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final canDownload = onDownload != null ||
        song.filePath.startsWith('spotify://') ||
        song.filePath.startsWith('youtube://') ||
        song.filePath.startsWith('http://') ||
        song.filePath.startsWith('https://');

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
                      child: Icon(
                        Icons.equalizer_rounded,
                        color: MelodiTheme.primaryGreen,
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
          color: isPlaying ? MelodiTheme.primaryGreen : MelodiTheme.onSurface,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          if (confidence != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: confidence! >= 0.9
                      ? const Color(0xFF4CAF50)
                      : confidence! >= 0.7
                          ? const Color(0xFFFFC107)
                          : const Color(0xFFF44336),
                ),
              ),
            ),
          Flexible(
            child: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MelodiTheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ),
          if (song.bitrate != null) ...[
            Text(
              ' · ',
              style: TextStyle(color: MelodiTheme.textMuted, fontSize: 11),
            ),
            Text(
              '${song.bitrate} kbps',
              style: TextStyle(
                color: MelodiTheme.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wrongMatchButton != null) wrongMatchButton!,
              _DownloadIndicator(song: song),
              if (showFavorite)
                IconButton(
                  icon: Icon(
                    song.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: song.isFavorite
                        ? MelodiTheme.primaryGreen
                        : MelodiTheme.textMuted,
                    size: 20,
                  ),
                  onPressed: onFavorite ??
                      () =>
                          context.read<LibraryProvider>().toggleFavorite(song),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz,
                    color: MelodiTheme.onSurfaceVariant, size: 20),
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
                    case 'download':
                      (onDownload ?? () => _downloadSong(context, song)).call();
                      break;
                    case 'share':
                      _shareSong(context, song);
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
                  if (canDownload)
                    PopupMenuItem(
                      value: 'download',
                      child: ListTile(
                        leading: const Icon(Icons.download_rounded),
                        title: Text(AppLocale.tr('download')),
                        dense: true,
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: const Icon(Icons.share_outlined),
                      title: Text(AppLocale.tr('share')),
                      dense: true,
                    ),
                  ),
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

  void _downloadSong(BuildContext context, SongModel song) {
    final downloads = context.read<DownloadProvider>();
    final status = downloads.getStatusForSong(song.title, song.artist);
    if (status == DownloadState.completed ||
        status == DownloadState.pending ||
        status == DownloadState.downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.tr('download_already_queued'))),
      );
      return;
    }

    final spotifyId = song.id.startsWith('spotify:')
        ? song.id.replaceFirst('spotify:', '')
        : song.id;
    final sourceVideoId = song.filePath.startsWith('youtube://')
        ? song.filePath.replaceFirst('youtube://', '')
        : RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(song.id)
            ? song.id
            : null;
    downloads.enqueueTrack(
      spotifyTrackId: spotifyId,
      title: song.title,
      artist: song.artist,
      album: song.album,
      sourceVideoId: sourceVideoId,
      expectedDurationMs: song.duration.inMilliseconds,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${song.title} · ${AppLocale.tr('download_queued')}"),
        backgroundColor: MelodiTheme.primaryGreen,
      ),
    );
  }

  Future<void> _shareSong(BuildContext context, SongModel song) async {
    try {
      await ShareService.instance.shareSong(song);
    } catch (error) {
      debugPrint('Share error: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.tr('share')),
          backgroundColor: MelodiTheme.errorRed,
        ),
      );
    }
  }
}

class _DownloadIndicator extends StatelessWidget {
  final SongModel song;
  const _DownloadIndicator({required this.song});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final status = provider.getStatusForSong(song.title, song.artist);
        if (status == null) return const SizedBox.shrink();
        final progress = provider.getProgressForSong(song.title, song.artist);

        switch (status) {
          case DownloadState.pending:
          case DownloadState.downloading:
            if (progress != null && progress > 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2,
                        color: MelodiTheme.primaryGreen,
                      ),
                      Text(
                        '${(progress * 100).toInt()}',
                        style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: MelodiTheme.primaryGreen),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MelodiTheme.primaryGreen,
                ),
              ),
            );
          case DownloadState.completed:
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.check_circle,
                  color: MelodiTheme.primaryGreen, size: 18),
            );
          case DownloadState.failed:
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.error, color: MelodiTheme.errorRed, size: 18),
            );
        }
      },
    );
  }
}
