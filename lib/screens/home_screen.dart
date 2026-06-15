import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/playlist_card.dart';
import '../models/song_model.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/playlist_model.dart';
import '../providers/playlist_provider.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentPage = 0;

  final List<Widget> _pages = const [
    _HomeTab(),
    LibraryScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleNotifier>();
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentPage,
              children: _pages,
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.darkDivider.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentPage,
          onTap: (index) => setState(() => _currentPage = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: AppLocale.tr('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.my_library_music_rounded),
              label: AppLocale.tr('library'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search_rounded),
              label: AppLocale.tr('search'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              label: AppLocale.tr('settings'),
            ),
          ],
          selectedFontSize: 11,
          unselectedFontSize: 11,
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer3<LibraryProvider, PlaylistProvider, LocaleNotifier>(
      builder: (context, library, playlistProvider, locale, _) {
        return RefreshIndicator(
          onRefresh: () async => await library.loadAll(),
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                title: Text(
                  AppLocale.tr('melodi'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  if (library.isScanning)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      tooltip: AppLocale.tr('import_music'),
                      onPressed: () => _showImportOptions(context),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: library.songs.isEmpty && !library.isLoading
                    ? _buildEmptyState(context)
                    : _buildContent(context, library, playlistProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note_rounded,
                size: 80, color: AppTheme.textTertiary),
            const SizedBox(height: 24),
            Text(
              AppLocale.tr('your_music_awaits'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocale.tr('import_songs_to_start'),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showImportOptions(context),
              icon: const Icon(Icons.library_music_rounded),
              label: Text(AppLocale.tr('import_music')),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, LibraryProvider library, PlaylistProvider playlistProvider) {
    final recentlyPlayed = library.recent.take(10).toList();
    final favorites = library.favorites.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recently Played
        if (recentlyPlayed.isNotEmpty) ...[
          _SectionHeader(
            title: AppLocale.tr('recently_played'),
            onSeeAll: () {},
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: recentlyPlayed.length,
              itemBuilder: (context, index) {
                final song = recentlyPlayed[index];
                return _RecentSongCard(
                  song: song,
                  onTap: () => context
                      .read<PlayerProvider>()
                      .playSong(song),
                );
              },
            ),
          ),
        ],
        // Favorites
        if (favorites.isNotEmpty) ...[
          _SectionHeader(
            title: AppLocale.tr('liked_songs'),
            onSeeAll: null,
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final song = favorites[index];
                return _RecentSongCard(
                  song: song,
                  onTap: () => context
                      .read<PlayerProvider>()
                      .playSong(song),
                );
              },
            ),
          ),
        ],
        // Albums
        if (library.albums.isNotEmpty) ...[
          _SectionHeader(
            title: AppLocale.tr('albums'),
            onSeeAll: null,
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: library.albums.length,
              itemBuilder: (context, index) {
                final album = library.albums[index];
                return AlbumCard(
                  album: album,
                  onTap: () => _navigateToAlbum(context, album),
                );
              },
            ),
          ),
        ],
        // Artists
        if (library.artists.isNotEmpty) ...[
          _SectionHeader(
            title: AppLocale.tr('popular_artists'),
            onSeeAll: null,
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: library.artists.length,
              itemBuilder: (context, index) {
                final artist = library.artists[index];
                return ArtistCard(
                  artist: artist,
                  onTap: () => _navigateToArtist(context, artist),
                );
              },
            ),
          ),
        ],
        // Playlists
        if (playlistProvider.playlists.isNotEmpty) ...[
          _SectionHeader(
            title: AppLocale.tr('playlists'),
            onSeeAll: null,
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: playlistProvider.playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlistProvider.playlists[index];
                return PlaylistCard(
                  playlist: playlist,
                  onTap: () => _navigateToPlaylist(context, playlist),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.darkDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              AppLocale.tr('import_music'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.library_music_rounded,
                    color: AppTheme.primaryColor),
              ),
              title: Text(AppLocale.tr('scan_media_library'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('import_from_apple_music'),
                  style: const TextStyle(color: AppTheme.textTertiary)),
              onTap: () {
                Navigator.pop(context);
                context.read<LibraryProvider>().scanMusic();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_open_rounded,
                    color: Colors.orange),
              ),
              title: Text(AppLocale.tr('browse_files'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('select_audio_files'),
                  style: const TextStyle(color: AppTheme.textTertiary)),
              onTap: () {
                Navigator.pop(context);
                context.read<LibraryProvider>().importFromFiles();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_special_rounded,
                    color: Colors.purple),
              ),
              title: Text(AppLocale.tr('import_from_folder_title'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('scan_specific_folder'),
                  style: const TextStyle(color: AppTheme.textTertiary)),
              onTap: () {
                Navigator.pop(context);
                context.read<LibraryProvider>().importFromDirectory();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToAlbum(BuildContext context, AlbumModel album) {
    final songs = context.read<LibraryProvider>().getSongsForAlbum(album);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumDetailScreen(album: album, songs: songs),
      ),
    );
  }

  void _navigateToArtist(BuildContext context, ArtistModel artist) {
    final songs = context.read<LibraryProvider>().getSongsForArtist(artist);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArtistDetailScreen(artist: artist, songs: songs),
      ),
    );
  }

  void _navigateToPlaylist(BuildContext context, PlaylistModel playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                AppLocale.tr('see_all'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentSongCard extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _RecentSongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.darkCard,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.albumArt != null
                    ? Image.memory(song.albumArt!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.music_note_rounded,
                            size: 40, color: AppTheme.textTertiary),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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

class _AlbumDetailScreen extends StatelessWidget {
  final AlbumModel album;
  final List<SongModel> songs;

  const _AlbumDetailScreen({required this.album, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(album.name),
      ),
      body: songs.isEmpty
          ? Center(child: Text(AppLocale.tr('no_songs'), style: const TextStyle(color: AppTheme.textSecondary)))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  onTap: () => context.read<PlayerProvider>().playFromQueue(songs, index),
                  onFavorite: () => context.read<LibraryProvider>().toggleFavorite(song),
                );
              },
            ),
    );
  }
}

class _ArtistDetailScreen extends StatelessWidget {
  final ArtistModel artist;
  final List<SongModel> songs;

  const _ArtistDetailScreen({required this.artist, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(artist.name),
      ),
      body: songs.isEmpty
          ? Center(
              child: Text(AppLocale.tr('no_songs'), style: const TextStyle(color: AppTheme.textSecondary)))
          : ListView.builder(
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
