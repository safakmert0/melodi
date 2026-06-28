import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/equalizer_sheet.dart';
import 'settings_screen.dart';
import 'playlist_detail_screen.dart';
import 'mixes_screen.dart';
import 'album_discovery_screen.dart';
import 'downloads_screen.dart';
import 'library_health_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToLibrary;
  const HomeScreen({super.key, this.onNavigateToLibrary});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleNotifier>();
    return Consumer3<LibraryProvider, PlaylistProvider, ConnectionProvider>(
      builder: (context, library, playlistProvider, conn, _) {
        return RefreshIndicator(
          onRefresh: () async => await library.loadAll(),
          color: MelodiTheme.primaryGreen,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Melodi',
                  style: MelodiTheme.heading(size: 28),
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
                          color: MelodiTheme.primaryGreen,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: MelodiTheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildQuickPicks(context, library),
              ),
              if (library.songs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildQuickActions(context),
                ),
              SliverToBoxAdapter(
                child: library.isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 100),
                          child: CircularProgressIndicator(
                            color: MelodiTheme.primaryGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : library.songs.isEmpty
                        ? _buildEmptyState(context)
                        : _buildContent(context, library, playlistProvider),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPicks(BuildContext context, LibraryProvider library) {
    if (library.songs.isEmpty) return const SizedBox.shrink();
    final recentlyPlayed = library.recent.take(6).toList();
    if (recentlyPlayed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timeGreeting(),
            style: MelodiTheme.heading(size: 24),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.2,
            ),
            itemCount: recentlyPlayed.length,
            itemBuilder: (context, index) {
              final song = recentlyPlayed[index];
              return _QuickPickCard(
                song: song,
                onTap: () => context.read<PlayerProvider>().playSong(song),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickActionItem(
        icon: Icons.wb_sunny_rounded,
        label: AppLocale.tr('mixes'),
        color: const Color(0xFFF39C12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MixesScreen()),
        ),
      ),
      _QuickActionItem(
        icon: Icons.explore_rounded,
        label: AppLocale.tr('album_discovery'),
        color: const Color(0xFF8E44AD),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AlbumDiscoveryScreen()),
        ),
      ),
      _QuickActionItem(
        icon: Icons.download_rounded,
        label: AppLocale.tr('downloads'),
        color: const Color(0xFF2980B9),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DownloadsScreen()),
        ),
      ),
      _QuickActionItem(
        icon: Icons.lyrics_rounded,
        label: AppLocale.tr('backfill_lyrics'),
        color: const Color(0xFF008080),
        onTap: () {},
      ),
      _QuickActionItem(
        icon: Icons.image_rounded,
        label: AppLocale.tr('backfill_art'),
        color: const Color(0xFFE91E63),
        onTap: () {},
      ),
      _QuickActionItem(
        icon: Icons.favorite_border_rounded,
        label: AppLocale.tr('library_health'),
        color: const Color(0xFF27AE60),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LibraryHealthScreen()),
        ),
      ),
      _QuickActionItem(
        icon: Icons.sync_rounded,
        label: AppLocale.tr('sync'),
        color: const Color(0xFF3F51B5),
        onTap: () {},
      ),
      _QuickActionItem(
        icon: Icons.tune_rounded,
        label: AppLocale.tr('equalizer'),
        color: const Color(0xFFFF8F00),
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => const EqualizerSheet(),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) => actions[index],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, size: 80, color: MelodiTheme.textMuted),
            const SizedBox(height: 24),
            Text(
              AppLocale.tr('your_music_awaits'),
              style: MelodiTheme.heading(size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocale.tr('import_songs_to_start'),
              style: const TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.library_music_rounded),
              label: Text(AppLocale.tr('import_music')),
              style: FilledButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
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

  Widget _buildContent(BuildContext context, LibraryProvider library, PlaylistProvider playlistProvider) {
    final recentlyPlayed = library.recent.take(10).toList();
    final favorites = library.favorites.take(10).toList();
    final recentlyAdded = library.songs.toList()..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    final recentAdded = recentlyAdded.take(10).toList();
    final playlists = playlistProvider.playlists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentlyPlayed.isNotEmpty)
          _SectionWidget(
            title: AppLocale.tr('recently_played'),
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: recentlyPlayed.length,
                itemBuilder: (context, i) {
                  final song = recentlyPlayed[i];
                  return _RecentSongCard(
                    song: song,
                    onTap: () => context.read<PlayerProvider>().playSong(song),
                  );
                },
              ),
            ),
          ),
        if (favorites.isNotEmpty)
          _SectionWidget(
            title: AppLocale.tr('liked_songs'),
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: favorites.length,
                itemBuilder: (context, i) {
                  final song = favorites[i];
                  return _RecentSongCard(
                    song: song,
                    onTap: () => context.read<PlayerProvider>().playSong(song),
                  );
                },
              ),
            ),
          ),
        if (recentAdded.isNotEmpty)
          _SectionWidget(
            title: AppLocale.tr('recently_added'),
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: recentAdded.length,
                itemBuilder: (context, i) {
                  final song = recentAdded[i];
                  return _RecentSongCard(
                    song: song,
                    onTap: () => context.read<PlayerProvider>().playSong(song),
                  );
                },
              ),
            ),
          ),
        if (playlists.isNotEmpty)
          _SectionWidget(
            title: AppLocale.tr('your_playlists'),
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: playlists.length,
                itemBuilder: (context, i) {
                  final playlist = playlists[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: playlist),
                      ),
                    ),
                    child: PlaylistCard(playlist: playlist),
                  );
                },
              ),
            ),
          ),
        if (library.albums.isNotEmpty)
          _SectionWidget(
            title: AppLocale.tr('albums'),
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: library.albums.length,
                itemBuilder: (context, i) => AlbumCard(album: library.albums[i]),
              ),
            ),
          ),
        if (library.artists.isNotEmpty)
          _SectionWidget(
            title: AppLocale.tr('artists'),
            child: SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: library.artists.length,
                itemBuilder: (context, i) => ArtistCard(artist: library.artists[i]),
              ),
            ),
          ),
      ],
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppLocale.tr('good_morning');
    if (hour < 18) return AppLocale.tr('good_afternoon');
    return AppLocale.tr('good_evening');
  }
}

class _QuickPickCard extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _QuickPickCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: MelodiTheme.containerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: song.albumArt != null
                  ? Image.memory(
                      song.albumArt!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: MelodiTheme.surfaceMid2,
                      child: const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppConstants.fontFamily,
              color: MelodiTheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionWidget({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            title,
            style: MelodiTheme.heading(size: 20),
          ),
        ),
        child,
      ],
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
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: song.albumArt != null
                    ? Image.memory(
                        song.albumArt!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Container(
                        color: MelodiTheme.surfaceMid2,
                        child: const Icon(Icons.music_note_rounded, size: 40, color: MelodiTheme.onSurfaceVariant),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppConstants.fontFamily,
                color: MelodiTheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppConstants.fontFamily,
                color: MelodiTheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _FadeSlideIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
