import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../models/playlist_model.dart';
import 'playlist_detail_screen.dart';
import 'create_playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTab;
  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                AppLocale.tr('library'),
                style: MelodiTheme.heading(size: 28),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: MelodiTheme.background.withValues(alpha: 0.85),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: MelodiTheme.primaryGreen,
                      unselectedLabelColor: MelodiTheme.onSurfaceVariant,
                      indicatorColor: MelodiTheme.primaryGreen,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                      tabs: [
                        Tab(text: AppLocale.tr('playlists')),
                        Tab(text: AppLocale.tr('artists')),
                        Tab(text: AppLocale.tr('albums')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PlaylistsTab(),
            _ArtistsTab(),
            _AlbumsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreatePlaylistScreen()),
        ),
        backgroundColor: MelodiTheme.primaryGreen,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _TabBarDelegate({required this.child});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _PlaylistsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<PlaylistProvider, LibraryProvider>(
      builder: (context, playlistProvider, library, _) {
        final playlists = playlistProvider.playlists;
        final favoritesCount = library.favorites.length;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MelodiTheme.likedGradientStart, MelodiTheme.likedGradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            '${AppLocale.tr('liked_songs')} ($favoritesCount)',
                            style: const TextStyle(
                              fontFamily: AppConstants.fontFamily,
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final playlist = playlists[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlist: playlist),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: MelodiTheme.containerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: MelodiTheme.surfaceMid2,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.queue_music_rounded, size: 40, color: MelodiTheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppConstants.fontFamily,
                                      color: MelodiTheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${playlist.songs?.length ?? 0} ${AppLocale.tr('songs')}',
                                    style: const TextStyle(
                                      fontFamily: AppConstants.fontFamily,
                                      color: MelodiTheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: playlists.length,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        );
      },
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final artists = library.artists;

        if (artists.isEmpty) {
          return Center(
            child: Text(
              AppLocale.tr('no_artists_found'),
              style: const TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 15),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: CircleAvatar(
                radius: 30,
                backgroundColor: MelodiTheme.surfaceMid2,
                child: Text(
                  artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontFamily: AppConstants.fontFamily,
                    color: MelodiTheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text(
                artist.name,
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurface,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                AppLocale.tr('artist'),
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: MelodiTheme.onSurfaceVariant),
            );
          },
        );
      },
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final albums = library.albums;

        if (albums.isEmpty) {
          return Center(
            child: Text(
              AppLocale.tr('no_albums_found'),
              style: const TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 15),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return ListTile(
              leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: MelodiTheme.surfaceMid2,
                ),
                child: const Icon(Icons.album_rounded, color: MelodiTheme.onSurfaceVariant),
              ),
              title: Text(
                album.name,
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurface,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                album.artist ?? '',
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              trailing: Text(
                '${album.songCount} ${AppLocale.tr('songs')}',
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
