import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/youtube_provider.dart';
import '../models/song_model.dart';
import '../services/youtube_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/wrong_match_button.dart';
import '../services/album_discovery_service.dart';
import '../providers/spotify_provider.dart';
import 'album_detail_screen.dart';
import 'artist_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showClear = false;
  bool _youtubeMode = false;
  Timer? _debounce;
  List<DiscoveredAlbum> _albumResults = [];
  List<DiscoveredArtist> _artistResults = [];
  bool _isSearchingRemote = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _performSearch(String query, bool youtubeMode) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _albumResults = [];
        _artistResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final searchProvider = context.read<SearchProvider>();
      final youtubeProvider = context.read<YouTubeProvider>();
      if (youtubeMode) {
        youtubeProvider.search(q);
      } else {
        searchProvider.search(q);
        _searchRemote(q);
      }
    });
  }

  Future<void> _searchRemote(String query) async {
    setState(() => _isSearchingRemote = true);
    final service = AlbumDiscoveryService();
    final albums = await service.searchAlbums(query, limit: 5);
    final artists = await service.searchArtists(query, limit: 5);
    if (mounted) {
      setState(() {
        _albumResults = albums;
        _artistResults = artists;
        _isSearchingRemote = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: false,
            onChanged: (value) {
              setState(() => _showClear = value.isNotEmpty);
              _performSearch(value, _youtubeMode);
            },
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: AppLocale.tr('what_to_listen'),
              hintStyle:
                  TextStyle(color: AppTheme.textTertiary, fontSize: 16),
              filled: true,
              fillColor: AppTheme.card,
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppTheme.textTertiary),
              suffixIcon: _showClear
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: AppTheme.textTertiary),
                      onPressed: () {
                        _searchController.clear();
                        context.read<SearchProvider>().clearResults();
                        context.read<YouTubeProvider>().clearResults();
                        setState(() => _showClear = false);
                        _searchFocus.unfocus();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        // Tab selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _TabButton(
                label: AppLocale.tr('songs'),
                isActive: !_youtubeMode,
                onTap: () {
                  if (_youtubeMode) {
                    setState(() => _youtubeMode = false);
                    if (_searchController.text.isNotEmpty) {
                      context.read<SearchProvider>().search(_searchController.text);
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: 'YouTube',
                isActive: _youtubeMode,
                onTap: () {
                  if (!_youtubeMode) {
                    setState(() => _youtubeMode = true);
                    if (_searchController.text.isNotEmpty) {
                      context.read<YouTubeProvider>().search(_searchController.text);
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Results
        Expanded(
          child: _youtubeMode ? _buildYouTubeResults() : _buildLocalResults(),
        ),
      ],
      ),
    );
  }

  Widget _buildLocalResults() {
    return Consumer3<SearchProvider, LibraryProvider, LocaleNotifier>(
      builder: (context, searchProvider, library, locale, _) {
        if (searchProvider.query.isEmpty) {
          return _buildBrowseSection(searchProvider);
        }
        if (searchProvider.isSearching) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          );
        }
        if (searchProvider.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  '${AppLocale.tr('no_results_for')} "${searchProvider.query}"',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (_albumResults.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    AppLocale.tr('albums'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16),
                    itemCount: _albumResults.length,
                    itemBuilder: (context, index) {
                      final album = _albumResults[index];
                      return _SearchAlbumCard(
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
            ],
            if (_artistResults.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    AppLocale.tr('artists'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16),
                    itemCount: _artistResults.length,
                    itemBuilder: (context, index) {
                      final artist = _artistResults[index];
                      return _SearchArtistCard(
                        artist: artist,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ArtistProfileScreen(
                              artistId: artist.id,
                              artistName: artist.name,
                              imageUrl: artist.imageUrl,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppLocale.tr('songs'),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = searchProvider.results[index];
                  final spotify = context.read<SpotifyProvider>();
                  final spotifyEntry = spotify.matchedTrackIds.entries
                      .where((e) => e.value == song.id)
                      .toList();
                  final spotifyTrackId = spotifyEntry.isNotEmpty
                      ? spotifyEntry.first.key
                      : null;
                  return SongTile(
                    song: song,
                    onTap: () {
                      context
                          .read<PlayerProvider>()
                          .playFromQueue(searchProvider.results, index);
                      searchProvider.addRecentSearch(searchProvider.query);
                    },
                    onFavorite: () =>
                        context.read<LibraryProvider>().toggleFavorite(song),
                    wrongMatchButton: spotifyTrackId != null
                        ? WrongMatchButton(
                            spotifyTrackId: spotifyTrackId,
                            title: song.title,
                            artist: song.artist,
                            onResolved: () {},
                          )
                        : null,
                  );
                },
                childCount: searchProvider.results.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYouTubeResults() {
    return Consumer<YouTubeProvider>(
      builder: (context, ytProvider, _) {
        if (ytProvider.query.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline_rounded,
                    size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  AppLocale.tr('youtube_search_hint'),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        if (ytProvider.isSearching) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          );
        }
        if (ytProvider.isDownloading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 16),
                Text(
                  ytProvider.downloadProgress ?? AppLocale.tr('loading_song'),
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }
        if (ytProvider.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  '${AppLocale.tr('no_results_for')} "${ytProvider.query}"',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: ytProvider.results.length,
          itemBuilder: (context, index) {
            final video = ytProvider.results[index];
            return _YouTubeResultTile(
              video: video,
              onTap: () async {
                final path = await ytProvider.playAudio(video.id, video.title);
                if (path != null && context.mounted) {
                  final song = SongModel(
                    id: 'yt_${video.id}',
                    title: video.title,
                    artist: video.author,
                    album: 'YouTube',
                    duration: video.duration,
                    filePath: path,
                    fileSize: 0,
                  );
                  context.read<PlayerProvider>().playSong(song);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocale.tr('download_failed')),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              onDownload: () async {
                final path = await ytProvider.downloadAudio(video.id, video.title);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(path != null
                          ? '${AppLocale.tr('download_complete')}: ${video.title}'
                          : AppLocale.tr('download_failed')),
                      backgroundColor: path != null ? AppTheme.primaryColor : AppTheme.errorColor,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBrowseSection(SearchProvider searchProvider) {
    return Consumer<LocaleNotifier>(
      builder: (context, locale, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Recent searches
            if (searchProvider.recentSearches.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocale.tr('recent_searches'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: searchProvider.clearRecentSearches,
                        child: Text(
                          AppLocale.tr('clear'),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recent = searchProvider.recentSearches[index];
                    return ListTile(
                      leading: Icon(Icons.history_rounded,
                          color: AppTheme.textTertiary),
                      title: Text(recent,
                          style:
                              TextStyle(color: AppTheme.textPrimary)),
                      trailing: Icon(Icons.arrow_upward_rounded,
                          color: AppTheme.textTertiary, size: 16),
                      onTap: () {
                        _searchController.text = recent;
                        _performSearch(recent, _youtubeMode);
                        setState(() => _showClear = true);
                      },
                    );
                  },
                  childCount: searchProvider.recentSearches.length,
                ),
              ),
            ],
            // Browse all
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.tr('browse_all'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Pop', 'Rock', 'Jazz', 'Classical',
                        'Electronic', 'Hip Hop', 'R&B', 'Metal',
                        'Folk', 'Blues', 'Reggae', 'Country',
                      ].map((genre) {
                        return ActionChip(
                          label: Text(genre),
                          onPressed: () {
                            _searchController.text = genre;
                            _performSearch(genre, _youtubeMode);
                            setState(() => _showClear = true);
                          },
                          backgroundColor: AppTheme.card,
                          labelStyle: TextStyle(
                            color: AppTheme.textPrimary,
                          ),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _YouTubeResultTile extends StatelessWidget {
  final YouTubeVideo video;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const _YouTubeResultTile({
    required this.video,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr = video.duration.inHours > 0
        ? '${video.duration.inHours}:${(video.duration.inMinutes % 60).toString().padLeft(2, '0')}:${(video.duration.inSeconds % 60).toString().padLeft(2, '0')}'
        : '${video.duration.inMinutes}:${(video.duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: AppTheme.card,
          child: video.thumbnailUrl != null
              ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.play_circle_outline, color: AppTheme.textTertiary))
              : Icon(Icons.play_circle_outline, color: AppTheme.textTertiary),
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              video.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            ' · $durationStr',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.download_rounded, size: 20),
        color: AppTheme.textSecondary,
        onPressed: onDownload,
      ),
    );
  }
}

class _SearchAlbumCard extends StatelessWidget {
  final DiscoveredAlbum album;
  final VoidCallback onTap;

  const _SearchAlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 140,
                height: 140,
                color: AppTheme.card,
                child: album.imageUrl != null
                    ? Image.network(album.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.album_rounded,
                            size: 40,
                            color: AppTheme.textTertiary))
                    : Icon(Icons.album_rounded,
                        size: 40, color: AppTheme.textTertiary),
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
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchArtistCard extends StatelessWidget {
  final DiscoveredArtist artist;
  final VoidCallback onTap;

  const _SearchArtistCard({
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.card,
              child: CircleAvatar(
                radius: 38,
                backgroundColor: AppTheme.cardHover,
                backgroundImage: artist.imageUrl != null
                    ? NetworkImage(artist.imageUrl!)
                    : null,
                child: artist.imageUrl == null
                    ? Icon(Icons.person_rounded,
                        size: 32, color: AppTheme.textTertiary)
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
