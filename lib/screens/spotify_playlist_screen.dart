import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/spotify_provider.dart';
import '../services/download_manager.dart';
import '../services/spotify_service.dart';
import '../utils/spotify_track_mapper.dart';
import 'now_playing_screen.dart';

class SpotifyPlaylistScreen extends StatefulWidget {
  const SpotifyPlaylistScreen({
    super.key,
    required this.playlist,
  });

  final SpotifyPlaylistItem playlist;

  @override
  State<SpotifyPlaylistScreen> createState() => _SpotifyPlaylistScreenState();
}

class _SpotifyPlaylistScreenState extends State<SpotifyPlaylistScreen> {
  late Future<List<SpotifyTrackItem>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _loadTracks();
  }

  Future<List<SpotifyTrackItem>> _loadTracks({bool refresh = false}) {
    return context.read<SpotifyProvider>().loadPlaylistTracks(
          widget.playlist,
          refresh: refresh,
        );
  }

  Future<void> _refresh() async {
    final future = _loadTracks(refresh: true);
    setState(() => _tracksFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(widget.playlist.name),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        actions: [
          IconButton(
            tooltip: AppLocale.tr('retry'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<SpotifyTrackItem>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: MelodiTheme.primaryGreen,
              ),
            );
          }

          if (snapshot.hasError) {
            return _SpotifyPlaylistMessage(
              icon: Icons.cloud_off_rounded,
              title: AppLocale.tr('spotify_playlist_load_failed'),
              actionLabel: AppLocale.tr('retry'),
              onAction: _refresh,
            );
          }

          final tracks = snapshot.data ?? const <SpotifyTrackItem>[];
          if (tracks.isEmpty) {
            final expectedTracks = widget.playlist.trackCount > 0;
            return _SpotifyPlaylistMessage(
              icon: expectedTracks
                  ? Icons.sync_problem_rounded
                  : Icons.queue_music_rounded,
              title: expectedTracks
                  ? AppLocale.tr('spotify_playlist_load_failed')
                  : AppLocale.tr('no_songs_in_playlist'),
              actionLabel: AppLocale.tr('retry'),
              onAction: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: MelodiTheme.primaryGreen,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(tracks)),
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, index) =>
                      _buildTrackTile(tracks, index),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<SpotifyTrackItem> tracks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: Column(
        children: [
          Hero(
            tag: 'spotify-playlist-${widget.playlist.id}',
            child: _NetworkArtwork(
              url: widget.playlist.imageUrl,
              size: 168,
              radius: 22,
              fallbackIcon: Icons.queue_music_rounded,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MelodiTheme.onSurface,
              fontSize: 25,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${tracks.length} ${AppLocale.tr('songs').toLowerCase()} · Spotify',
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _playTracks(tracks, 0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(AppLocale.tr('play_all')),
                  style: FilledButton.styleFrom(
                    backgroundColor: MelodiTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadAll(tracks),
                  icon: const Icon(Icons.download_for_offline_rounded),
                  label: Text(AppLocale.tr('download_all')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MelodiTheme.onSurface,
                    side: BorderSide(color: MelodiTheme.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(List<SpotifyTrackItem> tracks, int index) {
    final track = tracks[index];
    final song = SpotifyTrackMapper.toSong(track);
    final currentId = context.watch<PlayerProvider>().currentSong?.id;
    final isCurrent = currentId == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      onTap: () => _playTracks(tracks, index),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          _NetworkArtwork(
            url: track.albumImageUrl,
            size: 52,
            radius: 9,
            fallbackIcon: Icons.music_note_rounded,
          ),
          if (isCurrent)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.equalizer_rounded,
                color: MelodiTheme.primaryGreen,
              ),
            ),
        ],
      ),
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? MelodiTheme.primaryGreen : MelodiTheme.onSurface,
          fontSize: 15,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _subtitle(track),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: MelodiTheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing: Consumer<DownloadProvider>(
        builder: (context, downloads, _) {
          final status = downloads.getStatusForSong(
            track.name,
            SpotifyTrackMapper.artistLabel(track),
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status != null) _downloadStatusIcon(status),
              PopupMenuButton<_SpotifyTrackAction>(
                tooltip: AppLocale.tr('more'),
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: MelodiTheme.onSurfaceVariant,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _SpotifyTrackAction.play:
                      _playTracks(tracks, index);
                      break;
                    case _SpotifyTrackAction.download:
                      _downloadTrack(track);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _SpotifyTrackAction.play,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.play_arrow_rounded),
                      title: Text(AppLocale.tr('play')),
                    ),
                  ),
                  PopupMenuItem(
                    value: _SpotifyTrackAction.download,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.download_rounded),
                      title: Text(AppLocale.tr('download')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _downloadStatusIcon(DownloadState status) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: switch (status) {
        DownloadState.pending || DownloadState.downloading => SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MelodiTheme.primaryGreen,
            ),
          ),
        DownloadState.completed => Icon(
            Icons.offline_pin_rounded,
            size: 19,
            color: MelodiTheme.primaryGreen,
          ),
        DownloadState.failed => Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: MelodiTheme.errorRed,
          ),
      },
    );
  }

  String _subtitle(SpotifyTrackItem track) {
    final artist = SpotifyTrackMapper.artistLabel(track);
    final album = track.albumName;
    return album == null || album.isEmpty ? artist : '$artist · $album';
  }

  void _playTracks(List<SpotifyTrackItem> tracks, int index) {
    final songs = tracks.map(SpotifyTrackMapper.toSong).toList(growable: false);
    final playback = context.read<PlayerProvider>().playFromQueue(songs, index);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
    );
    playback.catchError((Object error, StackTrace stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocale.tr('playback_failed')}: $error'),
          backgroundColor: MelodiTheme.errorRed,
        ),
      );
    });
  }

  void _downloadTrack(SpotifyTrackItem track) {
    final downloads = context.read<DownloadProvider>();
    final artist = SpotifyTrackMapper.artistLabel(track);
    final status = downloads.getStatusForSong(track.name, artist);
    if (status == DownloadState.completed ||
        status == DownloadState.pending ||
        status == DownloadState.downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.tr('download_already_queued'))),
      );
      return;
    }

    final data = SpotifyTrackMapper.toDownload(track);
    downloads.enqueueTrack(
      spotifyTrackId: data['id']!,
      title: data['title']!,
      artist: data['artist']!,
      album: data['album'],
      imageUrl: data['imageUrl'],
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${track.name} · ${AppLocale.tr('download_queued')}'),
        backgroundColor: MelodiTheme.primaryGreen,
      ),
    );
  }

  void _downloadAll(List<SpotifyTrackItem> tracks) {
    final downloads = context.read<DownloadProvider>();
    final seenTrackIds = <String>{};
    final queued = tracks
        .where((track) {
          if (!seenTrackIds.add(track.id)) return false;
          final status = downloads.getStatusForSong(
            track.name,
            SpotifyTrackMapper.artistLabel(track),
          );
          return status == null || status == DownloadState.failed;
        })
        .map(SpotifyTrackMapper.toDownload)
        .toList(growable: false);

    if (queued.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.tr('download_already_queued'))),
      );
      return;
    }

    downloads.enqueuePlaylist(queued);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${queued.length} ${AppLocale.tr('songs').toLowerCase()} · ${AppLocale.tr('download_queued')}',
        ),
        backgroundColor: MelodiTheme.primaryGreen,
      ),
    );
  }
}

class _NetworkArtwork extends StatelessWidget {
  const _NetworkArtwork({
    required this.url,
    required this.size,
    required this.radius,
    required this.fallbackIcon,
  });

  final String? url;
  final double size;
  final double radius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MelodiTheme.containerHigh, MelodiTheme.surfaceHigh],
        ),
      ),
      child: Icon(
        fallbackIcon,
        color: MelodiTheme.primaryGreen,
        size: size * 0.4,
      ),
    );
    if (url == null || url!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _SpotifyPlaylistMessage extends StatelessWidget {
  const _SpotifyPlaylistMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: MelodiTheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SpotifyTrackAction { play, download }
