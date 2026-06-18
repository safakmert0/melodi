import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/spotify_provider.dart';
import '../services/album_discovery_service.dart';
import 'album_detail_screen.dart';

class ArtistProfileScreen extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String? imageUrl;

  const ArtistProfileScreen({
    super.key,
    required this.artistId,
    required this.artistName,
    this.imageUrl,
  });

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  final AlbumDiscoveryService _service = AlbumDiscoveryService();
  DiscoveredArtist? _artist;
  List<DiscoveredTrack> _topTracks = [];
  List<DiscoveredAlbum> _albums = [];
  List<DiscoveredArtist> _related = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final artist = await _service.getArtist(widget.artistId);
    final albums = await _service.getAlbumsForArtist(widget.artistId);
    final related = await _service.searchArtists(widget.artistName);

    List<DiscoveredTrack> topTracks = [];
    if (albums.isNotEmpty) {
      final firstAlbumTracks = await _service.getAlbumTracks(albums.first.id);
      topTracks = firstAlbumTracks.take(5).toList();
    }

    if (mounted) {
      setState(() {
        _artist = artist;
        _albums = albums;
        _topTracks = topTracks;
        _related = related.where((a) => a.id != widget.artistId).take(10).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(child: _buildArtistInfo(context)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      AppLocale.tr('top_tracks'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_topTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(AppLocale.tr('no_songs'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _topTracks[index];
                        final durationStr = track.durationMs > 0
                            ? '${(track.durationMs / 60000).floor()}:${((track.durationMs % 60000) / 1000).floor().toString().padLeft(2, '0')}'
                            : '';
                        return ListTile(
                          leading: SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}',
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
                              ? Text(durationStr,
                                  style: TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 12))
                              : null,
                          onTap: () {
                            final songs = _topTracks
                                .map((t) => DiscoveredTrackToSongModel(t))
                                .toList();
                            context
                                .read<PlayerProvider>()
                                .playFromQueue(songs, index);
                          },
                        );
                      },
                      childCount: _topTracks.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      AppLocale.tr('discography'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_albums.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(AppLocale.tr('no_albums_found'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = _albums[index];
                          return _AlbumGridCard(
                            album: album,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumDetailScreen(album: album),
                                ),
                              );
                            },
                          );
                        },
                        childCount: _albums.length,
                      ),
                    ),
                  ),
                if (_related.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        AppLocale.tr('related_artists'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 16),
                        itemCount: _related.length,
                        itemBuilder: (context, index) {
                          final artist = _related[index];
                          return _RelatedArtistCard(
                            artist: artist,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ArtistProfileScreen(
                                    artistId: artist.id,
                                    artistName: artist.name,
                                    imageUrl: artist.imageUrl,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_artist?.imageUrl != null)
              CachedNetworkImage(
                imageUrl: _artist!.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.card,
                  child: Icon(Icons.person_rounded,
                      size: 80, color: AppTheme.textTertiary),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.card,
                  child: Icon(Icons.person_rounded,
                      size: 80, color: AppTheme.textTertiary),
                ),
              )
            else
              Container(
                color: AppTheme.card,
                child: Center(
                  child: Icon(Icons.person_rounded,
                      size: 100, color: AppTheme.textTertiary),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.background,
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistInfo(BuildContext context) {
    final artist = _artist;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            artist?.name ?? widget.artistName,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (artist?.followers != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_formatFollowers(artist!.followers!)} ${AppLocale.tr('followers')}',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _FollowButton(
                isFollowing: _isFollowing,
                onToggle: () async {
                  final spotify = context.read<SpotifyProvider>();
                  bool success;
                  if (_isFollowing) {
                    success = await spotify.service.unfollowArtist(widget.artistId);
                  } else {
                    success = await spotify.service.followArtist(widget.artistId);
                  }
                  if (success) {
                    setState(() => _isFollowing = !_isFollowing);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? (_isFollowing
                                ? AppLocale.tr('following')
                                : AppLocale.tr('unfollow'))
                            : 'Failed'),
                        backgroundColor: success
                            ? AppTheme.primaryColor
                            : AppTheme.errorColor,
                      ),
                    );
                  }
                },
              ),
              if (_topTracks.isNotEmpty)
                const SizedBox(width: 12),
              if (_topTracks.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    final songs = _topTracks
                        .map((t) => DiscoveredTrackToSongModel(t))
                        .toList();
                    context
                        .read<PlayerProvider>()
                        .playFromQueue(songs, 0);
                  },
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: Text(AppLocale.tr('play')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFollowers(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

SongModel DiscoveredTrackToSongModel(DiscoveredTrack track) {
  return SongModel(
    id: 'spotify:${track.id}',
    title: track.name,
    artist: track.artist,
    album: '',
    duration: Duration(milliseconds: track.durationMs),
    filePath: '',
    fileSize: 0,
    trackNumber: track.trackNumber,
  );
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onToggle;

  const _FollowButton({
    required this.isFollowing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onToggle,
      icon: Icon(
        isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
        size: 18,
      ),
      label: Text(
        isFollowing ? AppLocale.tr('following') : AppLocale.tr('follow') ?? 'Follow',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: isFollowing
            ? AppTheme.cardHover
            : AppTheme.primaryColor,
        foregroundColor: isFollowing ? AppTheme.textPrimary : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _RelatedArtistCard extends StatelessWidget {
  final DiscoveredArtist artist;
  final VoidCallback onTap;

  const _RelatedArtistCard({
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: AppTheme.card,
              child: CircleAvatar(
                radius: 43,
                backgroundColor: AppTheme.cardHover,
                backgroundImage: artist.imageUrl != null
                    ? CachedNetworkImageProvider(artist.imageUrl!)
                    : null,
                child: artist.imageUrl == null
                    ? Icon(Icons.person_rounded,
                        size: 36, color: AppTheme.textTertiary)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              artist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
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

class _AlbumGridCard extends StatelessWidget {
  final DiscoveredAlbum album;
  final VoidCallback onTap;

  const _AlbumGridCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                color: AppTheme.card,
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: album.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppTheme.card,
                          child: Icon(Icons.album_rounded,
                              size: 40, color: AppTheme.textTertiary),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                            Icons.album_rounded,
                            size: 40,
                            color: AppTheme.textTertiary),
                      )
                    : Icon(Icons.album_rounded,
                        size: 40, color: AppTheme.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            album.year != null ? '${album.year}' : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
