import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/home/home_content.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_bottom_nav.dart';
import '../services/audio_service.dart';

/// Animated gradient background widget for the home screen
class HomeGradientBackground extends StatelessWidget {
  const HomeGradientBackground({
    super.key,
    required this.colors,
    this.tileSize = 60,
  });

  final List<Color> colors;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [const Color(0xFF0a0a0f), const Color(0xFF1a1a24), const Color(0xFF0d0d15)]
        : [const Color(0xFFF8F5F8), const Color(0xFFFFFFFF), const Color(0xFFF0F5F5)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(double.infinity, double.infinity),
            _HomeGradientPainter(
              colors: colors.isNotEmpty ? colors : gradientColors,
              tileSize: tileSize,
            ),
          );
        },
      ),
    );
  }
}

class _HomeGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double tileSize;

  _HomeGradientPainter({
    required this.colors,
    required this.tileSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final numTilesX = (size.width / tileSize).ceil() + 1;
    final numTilesY = (size.height / tileSize).ceil() + 1;

    for (int i = 0; i < numTilesX; i++) {
      for (int j = 0; j < numTilesY; j++) {
        paint.color = colors[(i + j) % colors.length];
        canvas.drawRect(
          Offset(i * tileSize, j * tileSize). & Size(tileSize, tileSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomeGradientPainter old) =>
      old.colors != colors || old.tileSize != tileSize;
}

/// Home screen - completely redesigned as a Spotify/Apple Music hybrid
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideInAnimation;
  bool _isGridView = true;
  DownloadQuality _currentQuality = DownloadQuality.high;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideInAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final downloadQuality = context.watch<DownloadQualityService>().quality;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Animated gradient background
          HomeGradientBackground(
            colors: _getGradientColors(context),
            tileSize: 80,
          ),

          // Main scrollable content
          CustomScrollView(
            key: const PageStorageKey('melodi-home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                forceElevated: false,
                title: const MelodiLogoHeader(),
                actions: [
                  _buildAppBarActions(context, downloadProvider),
                  _buildSearchButton(context),
                ],
              ),

              // Now Playing Bar
              if (player.isPlaying || player.currentSong != null)
                _buildNowPlayingSliver(context, player),

              // Library Section
              if (library.songs.isNotEmpty || library.albums.isNotEmpty ||
                  library.artists.isNotEmpty)
                _buildLibrarySection(context, library),

              // Quick Actions
              _buildQuickActionsSection(context),

              // Divider
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),

              // Recently Added
              _buildRecentlyAddedSection(context, library),

              // Divider
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),

              // Footer with bottom navigation
              _buildFooterSliver(context),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MelodiBottomNav(),
    );
  }

  List<Color> _getGradientColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        const Color(0xFF1a1a2e),
        const Color(0xFF16213e),
        const Color(0xFF0f3460),
      ];
    }
    return [
      const Color(0xFFF8F5F8),
      const Color(0xFFFFFFFF),
      const Color(0xFFF5F0F5),
    ];
  }

  Widget _buildAppBarActions(
      BuildContext context, DownloadProvider downloadProvider) {
    return IconButton(
      icon: const Icon(Icons.download),
      tooltip: 'Kütüphane',
      onPressed: () {
        // Navigate to library
      },
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Ara',
      onPressed: () {
        // Navigate to search
      },
    );
  }

  Widget _buildNowPlayingSliver(
      BuildContext context, PlayerProvider player) {
    final currentSong = player.currentSong;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blur: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: currentSong == null
            ? const SizedBox(height: 50)
            : Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: currentSong.albumArt != null
                        ? Image.memory(
                            currentSong.albumArt!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.music_note,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentSong.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.artist,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Controls
                  SizedBox(
                    width: 48,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              size: 24, color: Colors.black87),
                          onPressed: () =>
                              player.skipToPrevious(),
                        ),
                        IconButton(
                          icon: player.isPlaying
                              ? const Icon(Icons.pause, size: 24, color: Colors.black87)
                              : const Icon(Icons.play_arrow,
                                  size: 24, color: Colors.black87),
                          onPressed: () => player.isPlaying ? player.pause() : player.play(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next,
                              size: 24, color: Colors.black87),
                          onPressed: () => player.skipToNext(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLibrarySection(
      BuildContext context, LibraryProvider library) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kütüphane',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            // Quick stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(
                  icon: Icons.music_note,
                  label: '${library.songs.length} Şarkı',
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatCard(
                  icon: Icons.album,
                  label: '${library.albums.length} Albüm',
                  color: Colors.purple,
                ),
                _StatCard(
                  icon: Icons.person,
                  label: '${library.artists.length} Sanatçı',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick access grid
            const Text(
              'Hızlı Erişim',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickActionCard(
                    icon: Icons.download,
                    label: 'İndirmeler',
                    onTap: () {
                      // Navigate to downloads
                    },
                    color: Colors.green,
                  ),
                  _QuickActionCard(
                    icon: Icons.favorite,
                    label: 'Beğenilenler',
                    onTap: () {
                      // Navigate to liked songs
                    },
                    color: Colors.pink,
                  ),
                  _QuickActionCard(
                    icon: Icons.queue,
                    label: 'Kuyruk',
                    onTap: () {
                      // Navigate to queue
                    },
                    color: Colors.cyan,
                  ),
                  _QuickActionCard(
                    icon: Icons.library_books,
                    label: 'Playlists',
                    onTap: () {
                      // Navigate to playlists
                    },
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Text(
          'Önerilen',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyAddedSection(
      BuildContext context, LibraryProvider library) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Son Eklenen',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (library.songs.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Text('Henüz şarkı eklenmemiş'),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 8),
                  itemCount: library.songs.length > 6 ? 6 : library.songs.length,
                  itemBuilder: (context, index) {
                    final song = library.songs[index];
                    return _RecentlyAddedCard(song: song);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: kBottomNavigationBarHeight + 16,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blur: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: MelodiBottomNav(),
        ),
      ),
    );
  }
}

/// Stat card widget for library stats
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? color.withOpacity(0.1) : color.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action card widget
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor =
        isDark ? color.withOpacity(0.3) : color.withOpacity(0.15);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hoverColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recently added card widget
class _RecentlyAddedCard extends StatelessWidget {
  final SongModel song;

  const _RecentlyAddedCard({
    required this.song,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blur: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album art
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: song.albumArt != null
                  ? Image.memory(
                      song.albumArt!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Icon(
                        Icons.music_note,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          // Song info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Melodi logo header widget
class MelodiLogoHeader extends StatelessWidget {
  const MelodiLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.music_note,
            color: Colors.green,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Melodi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Melodi bottom navigation bar
class MelodiBottomNav extends StatelessWidget {
  const MelodiBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color navBackground =
        isDark ? Colors.grey[900]! : Colors.white;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: navBackground,
      elevation: 0,
      selectedItemColor: Colors.green,
      unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey[600],
      currentIndex: 0,
      onTap: (index) {
        // Handle navigation
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: 'Ana Sayfa',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books),
          label: 'Kütüphane',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.queue),
          label: 'Kuyruk',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Beğenilenler',
        ),
      ],
    );
  }
}