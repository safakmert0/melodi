import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/album_discovery_service.dart';
import '../models/song_model.dart';
import '../widgets/song_tile.dart';

class AlbumDetailScreen extends StatefulWidget {
  final DiscoveredAlbum album;
  final List<DiscoveredTrack> tracks;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    this.tracks = const [],
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final AlbumDiscoveryService _service = AlbumDiscoveryService();
  List<DiscoveredTrack> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    if (widget.tracks.isNotEmpty) {
      setState(() {
        _tracks = widget.tracks;
        _isLoading = false;
      });
      return;
    }
    final tracks = await _service.getAlbumTracks(widget.album.id);
    if (mounted) {
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(album.name),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded,
                color: AppTheme.textSecondary),
            onSelected: (value) async {
              if (value == 'add_all') {
                _addAllToPlaylist(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_all',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, size: 20,
                        color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(AppLocale.tr('add_to_playlist')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, album),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _playAll(context),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(AppLocale.tr('play_all')),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _addAllToPlaylist(context),
                          icon: const Icon(Icons.playlist_add, size: 20),
                          label: Text(AppLocale.tr('add_to_playlist')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: AppTheme.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: AppTheme.divider, height: 1),
                  ),
                ),
                if (_tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(AppLocale.tr('no_songs'),
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _tracks[index];
                        return _TrackListTile(
                          track: track,
                          index: index,
                          onTap: () => _playTrack(context, index),
                        );
                      },
                      childCount: _tracks.length,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, DiscoveredAlbum album) {
    final durationStr = _tracks.isNotEmpty
        ? '${_tracks.length} ${AppLocale.tr('songs')}'
        : '';
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 140,
              height: 140,
              color: AppTheme.card,
              child: album.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: album.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.card,
                        child: Icon(Icons.album_rounded,
                            size: 48, color: AppTheme.textTertiary),
                      ),
                      errorWidget: (_, __, ___) => Icon(Icons.album_rounded,
                          size: 48, color: AppTheme.textTertiary),
                    )
                  : Icon(Icons.album_rounded,
                      size: 48, color: AppTheme.textTertiary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  album.artist,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (album.year != null) '${album.year}',
                    if (album.trackCount != null)
                      '${album.trackCount} ${AppLocale.tr('songs')}',
                    durationStr,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _playAll(BuildContext context) {
    if (_tracks.isEmpty) return;
    final songs = _tracks.map((t) => _toSongModel(t)).toList();
    context.read<PlayerProvider>().playFromQueue(songs, 0);
  }

  void _playTrack(BuildContext context, int index) {
    final songs = _tracks.map((t) => _toSongModel(t)).toList();
    context.read<PlayerProvider>().playFromQueue(songs, index);
  }

  void _addAllToPlaylist(BuildContext context) {
    final songs = _tracks.map((t) => _toSongModel(t)).toList();
    final playlistProvider = context.read<PlaylistProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  AppLocale.tr('add_to_playlist'),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Divider(color: AppTheme.divider, height: 1),
              ...playlistProvider.playlists.map((pl) => ListTile(
                    title: Text(pl.name,
                        style: TextStyle(color: AppTheme.textPrimary)),
                    trailing: Icon(Icons.playlist_add,
                        color: AppTheme.textSecondary, size: 20),
                    onTap: () {
                      playlistProvider.addSongsToPlaylist(
                          pl.id, songs.map((s) => s.id).toList());
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${AppLocale.tr('added_to')} ${pl.name}'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  SongModel _toSongModel(DiscoveredTrack track) {
    return SongModel(
      id: 'spotify:${track.id}',
      title: track.name,
      artist: track.artist,
      album: widget.album.name,
      duration: Duration(milliseconds: track.durationMs),
      filePath: '',
      fileSize: 0,
      trackNumber: track.trackNumber,
      year: widget.album.year,
    );
  }
}

class _TrackListTile extends StatelessWidget {
  final DiscoveredTrack track;
  final int index;
  final VoidCallback onTap;

  const _TrackListTile({
    required this.track,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr = track.durationMs > 0
        ? '${(track.durationMs / 60000).floor()}:${((track.durationMs % 60000) / 1000).floor().toString().padLeft(2, '0')}'
        : '';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SizedBox(
        width: 24,
        child: Text(
          '${track.trackNumber}',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: durationStr.isNotEmpty
          ? Text(
              durationStr,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            )
          : null,
    );
  }
}
