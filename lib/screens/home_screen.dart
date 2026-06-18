import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/database_service.dart';
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
import '../providers/mix_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/download_provider.dart';
import '../widgets/auth_banner.dart';
import '../widgets/home_banners.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'playlist_detail_screen.dart';
import 'mixes_screen.dart';
import 'album_discovery_screen.dart';
import 'downloads_screen.dart';
import 'library_health_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentPage = 0;
  int _libraryTab = 0;

  void _switchToLibrary([int tab = 0]) {
    setState(() {
      _libraryTab = tab;
      _currentPage = 1;
    });
  }

  List<Widget> get _pages => [
    _HomeTab(onNavigateToLibrary: _switchToLibrary),
    LibraryScreen(initialTab: _libraryTab),
    SearchScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleNotifier>();
    return Scaffold(
      body: Column(
        children: [
          Consumer<ConnectionProvider>(
            builder: (context, conn, _) => AuthBanner(
              connection: conn,
              onTap: () => setState(() => _currentPage = 3),
            ),
          ),
          const HomeBanners(),
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
              color: AppTheme.divider.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentPage,
          onTap: (index) => setState(() => _currentPage = index),
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textTertiary,
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
  final void Function([int])? onNavigateToLibrary;
  const _HomeTab({this.onNavigateToLibrary});

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
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  if (library.isScanning)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
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
                child: _buildHeroGradient(context, library),
              ),
              SliverToBoxAdapter(
                child: library.isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 100),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : library.songs.isEmpty
                        ? _buildEmptyState(context)
                        : _buildContent(context, library, playlistProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroGradient(BuildContext context, LibraryProvider library) {
    if (library.songs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.6),
            AppTheme.primaryColor.withValues(alpha: 0.15),
            AppTheme.card,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.music_note_rounded,
                size: 120, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${library.songCount} ${AppLocale.tr('songs')}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocale.tr('your_music_awaits'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded,
                size: 80, color: AppTheme.textTertiary),
            const SizedBox(height: 24),
            Text(
              AppLocale.tr('your_music_awaits'),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocale.tr('import_songs_to_start'),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
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
            onSeeAll: () => onNavigateToLibrary?.call(0),
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
            onSeeAll: () => onNavigateToLibrary?.call(0),
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
            onSeeAll: () => onNavigateToLibrary?.call(1),
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
            onSeeAll: () => onNavigateToLibrary?.call(2),
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
        ...[
          _SectionHeader(
            title: AppLocale.tr('playlists'),
            onSeeAll: () => onNavigateToLibrary?.call(0),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: playlistProvider.playlists.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CreatePlaylistCard(
                    onCreate: () => _showCreatePlaylistDialog(context),
                  );
                }
                final playlist = playlistProvider.playlists[index - 1];
                return PlaylistCard(
                  playlist: playlist,
                  onTap: () => _navigateToPlaylist(context, playlist),
                  onEdit: () => _showRenamePlaylistDialog(context, playlist),
                  onDelete: () => _confirmDeletePlaylist(context, playlist),
                  onAddSongs: () => _navigateToPlaylist(context, playlist),
                );
              },
            ),
          ),
        ],
        // Discover
        ...[
          _SectionHeader(
            title: AppLocale.tr('album_discovery'),
            onSeeAll: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AlbumDiscoveryScreen()),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: 1,
              itemBuilder: (context, index) {
                return _DiscoverCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AlbumDiscoveryScreen()),
                  ),
                );
              },
            ),
          ),
        ],
        // Mixes
        ...[
          _SectionHeader(
            title: AppLocale.tr('mixes'),
            onSeeAll: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MixesScreen()),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: 3,
              itemBuilder: (context, index) {
                final mixItems = [
                  (
                    Icons.wb_sunny_rounded,
                    AppLocale.tr('daily_mix'),
                    AppLocale.tr('daily_mix'),
                    const Color(0xFFF39C12),
                  ),
                  (
                    Icons.radar_rounded,
                    AppLocale.tr('release_radar'),
                    AppLocale.tr('release_radar'),
                    const Color(0xFFE74C3C),
                  ),
                  (
                    Icons.explore_rounded,
                    AppLocale.tr('discover_weekly'),
                    AppLocale.tr('discover_weekly'),
                    const Color(0xFF8E44AD),
                  ),
                ];
                final item = mixItems[index];
                return _MixCard(
                  icon: item.$1,
                  title: item.$2,
                  subtitle: item.$3,
                  gradientColor: item.$4,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MixesScreen()),
                  ),
                );
              },
            ),
          ),
        ],
        // Library Health
        _LibraryHealthCard(),
        const SizedBox(height: 8),
        // Downloads
        Consumer<DownloadProvider>(
          builder: (context, dp, _) {
            if (dp.totalCount == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.6),
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                        AppTheme.card,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.download_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.tr('downloads'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dp.completedCount} ${AppLocale.tr('completed')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dp.activeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dp.activeCount}',
                            style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.white.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocale.tr('new_playlist'),
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: AppLocale.tr('playlist_name'),
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await context
                    .read<PlaylistProvider>()
                    .createPlaylist(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(AppLocale.tr('create'),
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
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
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              AppLocale.tr('import_music'),
              style: TextStyle(
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
                child: Icon(Icons.library_music_rounded,
                    color: AppTheme.primaryColor),
              ),
              title: Text(AppLocale.tr('scan_media_library'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('import_from_apple_music'),
                  style: TextStyle(color: AppTheme.textTertiary)),
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
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('select_audio_files'),
                  style: TextStyle(color: AppTheme.textTertiary)),
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
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(AppLocale.tr('scan_specific_folder'),
                  style: TextStyle(color: AppTheme.textTertiary)),
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

  void _showRenamePlaylistDialog(BuildContext context, PlaylistModel playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocale.tr('rename_playlist'),
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<PlaylistProvider>().renamePlaylist(playlist.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: Text(AppLocale.tr('rename'),
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocale.tr('delete_playlist'),
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '${AppLocale.tr('delete_playlist_warning')} "${playlist.name}"?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<PlaylistProvider>().deletePlaylist(playlist.id);
              Navigator.pop(ctx);
            },
            child: Text(AppLocale.tr('delete'),
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
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
            style: TextStyle(
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
                style: TextStyle(
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
                color: AppTheme.card,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.albumArt != null
                    ? Image.memory(song.albumArt!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.card,
                        child: Icon(Icons.music_note_rounded,
                            size: 40, color: AppTheme.textTertiary),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

class _CreatePlaylistCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _CreatePlaylistCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCreate,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              AppLocale.tr('create_playlist'),
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color gradientColor;
  final VoidCallback onTap;

  const _MixCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientColor.withValues(alpha: 0.7),
              gradientColor.withValues(alpha: 0.2),
              AppTheme.card,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DiscoverCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.6),
              AppTheme.primaryColor.withValues(alpha: 0.15),
              AppTheme.card,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.explore_rounded,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocale.tr('album_discovery'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.tr('new_releases'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryHealthCard extends StatefulWidget {
  @override
  State<_LibraryHealthCard> createState() => _LibraryHealthCardState();
}

class _LibraryHealthCardState extends State<_LibraryHealthCard> {
  int _issueCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final missingArt = await db.getTracksMissingArt();
    final missingMeta = await db.getTracksMissingMetadata();
    _issueCount = missingArt.length + missingMeta.length;
    _loaded = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LibraryHealthScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _issueCount > 0
                    ? Colors.orange.withValues(alpha: 0.6)
                    : AppTheme.primaryColor.withValues(alpha: 0.6),
                _issueCount > 0
                    ? Colors.orange.withValues(alpha: 0.15)
                    : AppTheme.primaryColor.withValues(alpha: 0.15),
                AppTheme.card,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _issueCount > 0 ? Icons.favorite_border_rounded : Icons.favorite_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.tr('library_health'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _issueCount > 0
                          ? '$_issueCount ${AppLocale.tr('issues_found')}'
                          : AppLocale.tr('no_issues'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(album.name),
      ),
      body: songs.isEmpty
          ? Center(child: Text(AppLocale.tr('no_songs'), style: TextStyle(color: AppTheme.textSecondary)))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  onTap: () => context.read<PlayerProvider>().playFromQueue(songs, index),
                  onFavorite: () => context.read<LibraryProvider>().toggleFavorite(song),
                  onViewArtist: () => _navigateToArtistFromSong(context, song),
                );
              },
              ),
        );
  }

  void _navigateToArtistFromSong(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final artists = lib.artists.where((a) => a.name == song.artist).toList();
    if (artists.isNotEmpty) {
      final artistSongs = lib.getSongsForArtist(artists.first);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ArtistDetailScreen(artist: artists.first, songs: artistSongs),
        ),
      );
    }
  }
}

class _ArtistDetailScreen extends StatelessWidget {
  final ArtistModel artist;
  final List<SongModel> songs;

  const _ArtistDetailScreen({required this.artist, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(artist.name),
      ),
      body: songs.isEmpty
          ? Center(
              child: Text(AppLocale.tr('no_songs'), style: TextStyle(color: AppTheme.textSecondary)))
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
                  onViewAlbum: () => _navigateToAlbumFromSong(context, song),
                );
              },
            ),
     );
  }
}

void _navigateToAlbumFromSong(BuildContext context, SongModel song) {
  final lib = context.read<LibraryProvider>();
  final albums = lib.albums.where((a) => a.name == song.album && a.artist == song.artist).toList();
  if (albums.isNotEmpty) {
    final albumSongs = lib.getSongsForAlbum(albums.first);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumDetailScreen(album: albums.first, songs: albumSongs),
      ),
    );
  }
}
