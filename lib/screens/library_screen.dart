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

  Future<void> _onRefresh() async {
    await context.read<LibraryProvider>().refresh();
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
              ? Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : library.songs.isEmpty
                  ? _buildEmptyLibrary(context)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppTheme.primaryColor,
                          child: _SongsTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppTheme.primaryColor,
                          child: _AlbumsTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppTheme.primaryColor,
                          child: _ArtistsTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppTheme.primaryColor,
                          child: _GenresTab(),
                        ),
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
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocale.tr('import_music_from_device'),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
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

class _SongsTab extends StatefulWidget {
  @override
  State<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<_SongsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, PlayerProvider>(
      builder: (context, library, player, _) {
        final allSongs = library.songs;
        final songs = _searchQuery.isEmpty
            ? allSongs
            : library.search(_searchQuery);
        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppLocale.tr('what_to_listen'),
                  hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textTertiary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppTheme.textTertiary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Recently Added section (only when not searching)
            if (_searchQuery.isEmpty && library.recent.isNotEmpty)
              _RecentlyAddedSection(recent: library.recent),
            // Sort & count bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${songs.length} ${AppLocale.tr('songs').toLowerCase()}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.sort_rounded,
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
}

class _RecentlyAddedSection extends StatelessWidget {
  final List<SongModel> recent;

  const _RecentlyAddedSection({required this.recent});

  @override
  Widget build(BuildContext context) {
    final display = recent.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            AppLocale.tr('recently_played'),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: display.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final song = display[index];
              return GestureDetector(
                onTap: () => context.read<PlayerProvider>().playSong(song),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (song.albumArt != null && song.albumArt!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(song.albumArt!, width: 36, height: 36, fit: BoxFit.cover),
                        )
                      else
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.cardHover,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.music_note_rounded, size: 18, color: AppTheme.textTertiary),
                        ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(song.artist, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
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

class _AlbumsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final albums = library.albums;
        if (albums.isEmpty) {
          return Center(
            child: Text(AppLocale.tr('no_albums_found'),
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                      color: AppTheme.card,
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
                                    color: AppTheme.cardHover,
                                    child: Center(
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
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${album.artist} · ${album.songCount} ${AppLocale.tr('songs').toLowerCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
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
            ),
          ],
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
      backgroundColor: AppTheme.background,
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
                backgroundColor: AppTheme.card,
                backgroundImage: artist.image != null
                    ? MemoryImage(artist.image!)
                    : null,
                child: artist.image == null
                    ? Icon(Icons.person_rounded,
                        color: AppTheme.textTertiary.withValues(alpha: 0.7))
                    : null,
              ),
              title: Text(artist.name,
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(
                '${artist.songCount} ${AppLocale.tr('songs').toLowerCase()} · ${artist.albumCount} ${AppLocale.tr('albums').toLowerCase()}',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right,
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
      backgroundColor: AppTheme.background,
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
          );
        },
      ),
    );
  }
}

class _GenresTab extends StatelessWidget {
  String _genreEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('rock')) return '🎸';
    if (n.contains('pop')) return '🎤';
    if (n.contains('jazz')) return '🎷';
    if (n.contains('classical') || n.contains('klasik')) return '🎻';
    if (n.contains('hip hop') || n.contains('rap')) return '🎧';
    if (n.contains('rb') || n.contains('rhythm') || n.contains('blues')) return '🎵';
    if (n.contains('country')) return '🤠';
    if (n.contains('edm') || n.contains('electronic') || n.contains('dance') || n.contains('elektronik')) return '🎹';
    if (n.contains('metal')) return '🤘';
    if (n.contains('folk') || n.contains('halk')) return '🪕';
    if (n.contains('reggae')) return '🏝️';
    if (n.contains('latin') || n.contains('salsa')) return '💃';
    if (n.contains('punk')) return '⚡';
    if (n.contains('indie')) return '🎸';
    if (n.contains('soul')) return '🎙️';
    if (n.contains('funk')) return '🕺';
    if (n.contains('ambient')) return '🌌';
    if (n.contains('soundtrack') || n.contains('film') || n.contains('score')) return '🎬';
    if (n.contains('blues')) return '🎸';
    if (n.contains('reggaeton')) return '🎶';
    if (n.contains('gospel') || n.contains('religious') || n.contains('ilahi')) return '⛪';
    if (n.contains('children') || n.contains('çocuk')) return '🧒';
    if (n.contains('comedy') || n.contains('komedi')) return '😂';
    if (n.contains('spoken word') || n.contains('audiobook') || n.contains('sesli')) return '📖';
    return '🎵';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final genres = library.genres;
        if (genres.isEmpty) {
          return Center(
            child: Text(AppLocale.tr('no_genres_found'),
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
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_genreEmoji(genre.name), style: TextStyle(fontSize: 22)),
              ),
              title: Text(genre.name,
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${genre.songCount} ${AppLocale.tr('songs').toLowerCase()}',
                  style: TextStyle(color: AppTheme.textSecondary)),
              trailing: Icon(Icons.chevron_right,
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
      backgroundColor: AppTheme.background,
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
