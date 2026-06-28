import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/album_discovery_service.dart';
import 'album_detail_screen.dart';

class AlbumDiscoveryScreen extends StatefulWidget {
  const AlbumDiscoveryScreen({super.key});

  @override
  State<AlbumDiscoveryScreen> createState() => _AlbumDiscoveryScreenState();
}

class _AlbumDiscoveryScreenState extends State<AlbumDiscoveryScreen> {
  final AlbumDiscoveryService _service = AlbumDiscoveryService();
  List<DiscoveredAlbum> _newReleases = [];
  List<DiscoveredAlbum> _genreAlbums = [];
  bool _isLoadingNew = true;
  bool _isLoadingGenre = true;
  String _selectedGenre = 'Pop';

  static const List<String> _genres = [
    'Pop', 'Rock', 'Jazz', 'Classical', 'Electronic',
    'Hip-Hop', 'R&B', 'Metal', 'Folk', 'Blues',
    'Reggae', 'Country', 'Indie', 'Soul', 'Funk',
  ];

  @override
  void initState() {
    super.initState();
    _loadNewReleases();
    _loadGenreAlbums(_selectedGenre);
  }

  Future<void> _loadNewReleases() async {
    final releases = await _service.getNewReleases();
    if (mounted) {
      setState(() {
        _newReleases = releases;
        _isLoadingNew = false;
      });
    }
  }

  Future<void> _loadGenreAlbums(String genre) async {
    setState(() => _isLoadingGenre = true);
    final albums = await _service.discoverByGenre(genre);
    if (mounted) {
      setState(() {
        _genreAlbums = albums;
        _isLoadingGenre = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('album_discovery')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadNewReleases();
          await _loadGenreAlbums(_selectedGenre);
        },
        color: MelodiTheme.primaryGreen,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // New Releases
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppLocale.tr('new_releases'),
                  style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _isLoadingNew
                  ? SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: MelodiTheme.primaryGreen, strokeWidth: 2),
                      ),
                    )
                  : _newReleases.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(AppLocale.tr('no_albums_found'),
                                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
                          ),
                        )
                      : SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 16),
                            itemCount: _newReleases.length,
                            itemBuilder: (context, index) {
                              final album = _newReleases[index];
                              return _AlbumCard(
                                album: album,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AlbumDetailScreen(album: album),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
            // Browse by Genre
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  AppLocale.tr('browse_genre'),
                  style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: _genres.length,
                  itemBuilder: (context, index) {
                    final genre = _genres[index];
                    final isSelected = genre == _selectedGenre;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(genre),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedGenre = genre);
                          _loadGenreAlbums(genre);
                        },
                        selectedColor: MelodiTheme.primaryGreen,
                        backgroundColor: MelodiTheme.containerLow,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : MelodiTheme.onSurface,
                          fontSize: 13,
                        ),
                        side: BorderSide.none,
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _isLoadingGenre
                  ? SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: MelodiTheme.primaryGreen, strokeWidth: 2),
                      ),
                    )
                  : _genreAlbums.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(AppLocale.tr('no_albums_found'),
                                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: _genreAlbums.length,
                          itemBuilder: (context, index) {
                            final album = _genreAlbums[index];
                            return _AlbumCard(
                              album: album,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumDetailScreen(album: album),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final DiscoveredAlbum album;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 150,
                height: 150,
                color: MelodiTheme.containerLow,
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: album.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: MelodiTheme.containerLow,
                          child: Icon(Icons.album_rounded,
                              size: 48, color: MelodiTheme.textMuted),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                            Icons.album_rounded,
                            size: 48,
                            color: MelodiTheme.textMuted),
                      )
                    : Icon(Icons.album_rounded,
                        size: 48, color: MelodiTheme.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MelodiTheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            if (album.year != null)
              Text(
                '${album.year}',
                style: TextStyle(
                  color: MelodiTheme.textMuted,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
