import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/song_tile.dart';
import '../models/song_model.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              title: const Text(
                'Library',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              floating: true,
              pinned: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textTertiary,
                tabs: const [
                  Tab(text: 'Songs'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Artists'),
                  Tab(text: 'Genres'),
                ],
              ),
            ),
          ],
          body: library.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : library.songs.isEmpty
                  ? _buildEmptyLibrary(context)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _SongsTab(),
                        _AlbumsTab(),
                        _ArtistsTab(),
                        _GenresTab(),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildEmptyLibrary(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music_outlined,
              size: 80, color: AppTheme.textTertiary),
          const SizedBox(height: 24),
          const Text(
            'Your library is empty',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import music from your device',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.read<LibraryProvider>().scanMusic(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan Music Library'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, PlayerProvider>(
      builder: (context, library, player, _) {
        final songs = library.songs;
        return Column(
          children: [
            // Sort & Filter bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${songs.length} songs',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    onSelected: (value) {},
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'title',
                        child: Text('Sort by Title'),
                      ),
                      const PopupMenuItem(
                        value: 'artist',
                        child: Text('Sort by Artist'),
                      ),
                      const PopupMenuItem(
                        value: 'album',
                        child: Text('Sort by Album'),
                      ),
                      const PopupMenuItem(
                        value: 'duration',
                        child: Text('Sort by Duration'),
                      ),
                      const PopupMenuItem(
                        value: 'date',
                        child: Text('Sort by Date Added'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final isPlaying = player.currentSong?.id == song.id;
                  return SongTile(
                    song: song,
                    isPlaying: isPlaying,
                    onTap: () =>
                        player.playFromQueue(songs, index),
                    onFavorite: () =>
                        context.read<LibraryProvider>().toggleFavorite(song),
                  );
                },
              ),
            ),
          ],
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
          return const Center(
            child: Text('No albums found',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return GestureDetector(
              onTap: () {
                final songs = library.getSongsForAlbum(album);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AlbumGridDetailScreen(
                      album: album,
                      songs: songs,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardHover,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Center(
                          child: Icon(Icons.album_rounded,
                              size: 48, color: AppTheme.textTertiary),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${album.artist} · ${album.songCount} songs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
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
        );
      },
    );
  }
}

class _AlbumGridDetailScreen extends StatelessWidget {
  final dynamic album;
  final List<SongModel> songs;

  const _AlbumGridDetailScreen({required this.album, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: Text(album.name)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () =>
                context.read<PlayerProvider>().playFromQueue(songs, index),
            onFavorite: () =>
                context.read<LibraryProvider>().toggleFavorite(song),
          );
        },
      ),
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
          return const Center(
            child: Text('No artists found',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.darkCard,
                child: Icon(Icons.person_rounded,
                    color: AppTheme.textTertiary.withValues(alpha: 0.7)),
              ),
              title: Text(artist.name,
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(
                '${artist.songCount} songs · ${artist.albumCount} albums',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: AppTheme.textTertiary),
              onTap: () {
                final songs = library.getSongsForArtist(artist);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ArtistDetailScreen(
                      artistName: artist.name,
                      songs: songs,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ArtistDetailScreen extends StatelessWidget {
  final String artistName;
  final List<SongModel> songs;

  const _ArtistDetailScreen(
      {required this.artistName, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: Text(artistName)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () =>
                context.read<PlayerProvider>().playFromQueue(songs, index),
            onFavorite: () =>
                context.read<LibraryProvider>().toggleFavorite(song),
          );
        },
      ),
    );
  }
}

class _GenresTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final genres = library.genres;
        if (genres.isEmpty) {
          return const Center(
            child: Text('No genres found',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final genre = genres[index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_rounded,
                    color: AppTheme.textSecondary),
              ),
              title: Text(genre.name,
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${genre.songCount} songs',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppTheme.textTertiary),
              onTap: () {
                final songs = library.getSongsForGenre(genre);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _GenreDetailScreen(
                      genreName: genre.name,
                      songs: songs,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GenreDetailScreen extends StatelessWidget {
  final String genreName;
  final List<SongModel> songs;

  const _GenreDetailScreen(
      {required this.genreName, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: Text(genreName)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () =>
                context.read<PlayerProvider>().playFromQueue(songs, index),
            onFavorite: () =>
                context.read<LibraryProvider>().toggleFavorite(song),
          );
        },
      ),
    );
  }
}
