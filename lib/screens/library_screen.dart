import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/song_tile.dart';
import '../models/song_model.dart';
import '../models/album_model.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTab;
  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
  }



  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, LocaleNotifier>(
      builder: (context, library, locale, _) {
        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              title: Text(
                AppLocale.tr('library'),
                style: const TextStyle(
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
                tabs: [
                  Tab(text: AppLocale.tr('songs')),
                  Tab(text: AppLocale.tr('albums')),
                  Tab(text: AppLocale.tr('artists')),
                  Tab(text: AppLocale.tr('genres')),
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
          Icon(Icons.library_music_outlined,
              size: 80, color: AppTheme.textTertiary),
          const SizedBox(height: 24),
          Text(
            AppLocale.tr('your_library_is_empty'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocale.tr('import_music_from_device'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.read<LibraryProvider>().scanMusic(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocale.tr('scan_music_library')),
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
                    '${songs.length} ${AppLocale.tr('songs').toLowerCase()}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'title':
                          library.setSortField(SongSortField.title);
                          break;
                        case 'artist':
                          library.setSortField(SongSortField.artist);
                          break;
                        case 'album':
                          library.setSortField(SongSortField.album);
                          break;
                        case 'duration':
                          library.setSortField(SongSortField.duration);
                          break;
                        case 'date':
                          library.setSortField(SongSortField.dateAdded);
                          break;
                        case 'toggleDirection':
                          library.toggleSortDirection();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'title',
                        child: Row(
                          children: [
                            Expanded(child: Text(AppLocale.tr('sort_by_title'))),
                            if (library.sortField == SongSortField.title)
                              Icon(library.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'artist',
                        child: Row(
                          children: [
                            Expanded(child: Text(AppLocale.tr('sort_by_artist'))),
                            if (library.sortField == SongSortField.artist)
                              Icon(library.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'album',
                        child: Row(
                          children: [
                            Expanded(child: Text(AppLocale.tr('sort_by_album'))),
                            if (library.sortField == SongSortField.album)
                              Icon(library.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duration',
                        child: Row(
                          children: [
                            Expanded(child: Text(AppLocale.tr('sort_by_duration'))),
                            if (library.sortField == SongSortField.duration)
                              Icon(library.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'date',
                        child: Row(
                          children: [
                            Expanded(child: Text(AppLocale.tr('sort_by_date_added'))),
                            if (library.sortField == SongSortField.dateAdded)
                              Icon(library.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'toggleDirection',
                        child: Row(
                          children: [
                            Icon(
                              library.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16, color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(library.sortAscending ? 'A-Z' : 'Z-A'),
                          ],
                        ),
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
                    onViewAlbum: () => _navigateToAlbum(context, song),
                    onViewArtist: () => _navigateToArtist(context, song),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAlbum(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final albums = lib.albums.where((a) => a.name == song.album && a.artist == song.artist).toList();
    if (albums.isNotEmpty) {
      final albumSongs = lib.getSongsForAlbum(albums.first);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AlbumGridDetailScreen(album: albums.first, songs: albumSongs),
        ),
      );
    }
  }

  void _navigateToArtist(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final artists = lib.artists.where((a) => a.name == song.artist).toList();
    if (artists.isNotEmpty) {
      final artistSongs = lib.getSongsForArtist(artists.first);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ArtistDetailScreen(artistName: artists.first.name, songs: artistSongs),
        ),
      );
    }
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
            child: Text(AppLocale.tr('no_albums_found'),
                style: const TextStyle(color: AppTheme.textSecondary)),
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
            final songs = library.getSongsForAlbum(album);
            final artBytes = songs.isNotEmpty ? songs.first.albumArt : null;
            return GestureDetector(
              onTap: () {
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
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: artBytes != null && artBytes.isNotEmpty
                            ? Image.memory(artBytes, fit: BoxFit.cover, width: double.infinity)
                            : Container(
                                color: AppTheme.darkCardHover,
                                child: const Center(
                                  child: Icon(Icons.album_rounded, size: 48, color: AppTheme.textTertiary),
                                ),
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
                            '${album.artist} · ${album.songCount} ${AppLocale.tr('songs').toLowerCase()}',
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
  final AlbumModel album;
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
            onViewAlbum: () {},
            onViewArtist: () => _navigateToArtist(context, song),
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
          return Center(
            child: Text(AppLocale.tr('no_artists_found'),
                style: const TextStyle(color: AppTheme.textSecondary)),
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
                '${artist.songCount} ${AppLocale.tr('songs').toLowerCase()} · ${artist.albumCount} ${AppLocale.tr('albums').toLowerCase()}',
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
            onViewAlbum: () => _navigateToAlbum(context, song),
            onViewArtist: () {},
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
          return Center(
            child: Text(AppLocale.tr('no_genres_found'),
                style: const TextStyle(color: AppTheme.textSecondary)),
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
              subtitle: Text('${genre.songCount} ${AppLocale.tr('songs').toLowerCase()}',
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
            onViewAlbum: () => _navigateToAlbum(context, song),
            onViewArtist: () => _navigateToArtist(context, song),
          );
        },
      ),
    );
  }
}
