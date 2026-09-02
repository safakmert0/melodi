import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Home content - main music content area with featured playlists, recently played, etc.
class HomeContent extends StatefulWidget final {
  final LibraryProvider library;
  final PlaylistProvider playlists;

  const HomeContent({
    required this.library,
    required this.playlists,
    super.key,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProvider = context.watch<DownloadProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured section
          _buildFeaturedSection(context),

          const SizedBox(height: 24),

          // Recently played
          _buildRecentlyPlayedSection(context),

          const SizedBox(height: 24),

          // Quick downloads
          _buildQuickDownloadsSection(context, downloadProvider),

          const SizedBox(height: 24),

          // Playlists
          _buildPlaylistsSection(context),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Önerilen Karışım',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 8),
            itemCount: 4,
            itemBuilder: (context, index) {
              return _FeaturedCard(
                title: 'Karışım ${index + 1}',
                subtitle: 'Yarının en popüler şarkılar',
                onTap: () {
                  // Play mix
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyPlayedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Son Dinlenen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 8),
            itemCount: 4,
            itemBuilder: (context, index) {
              return _RecentlyPlayedCard(
                title: 'Şarkı ${index + 1}',
                artist: 'Sanatçı ${index + 1}',
                onTap: () {
                  // Play song
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDownloadsSection(
      BuildContext context, DownloadProvider downloadProvider) {
    final activeDownloads = downloadProvider.activeDownloads;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktif İndirmeler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (activeDownloads.isEmpty)
          const Text('Aktif indirme yok')
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 8),
              itemCount: activeDownloads.length > 3 ? 3 : activeDownloads.length,
              itemBuilder: (context, index) {
                final task = activeDownloads[index];
                return _ActiveDownloadCard(task: task);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Playlists',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 8),
            itemCount: widget.playlists.playlists.length > 4 ? 4 : widget.playlists.playlists.length,
            itemBuilder: (context, index) {
              final playlist = widget.playlists.playlists[index];
              return _PlaylistCard(
                name: playlist.name,
                songCount: playlist.songs.length,
                onTap: () {
                  // Navigate to playlist
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Featured card widget
class _FeaturedCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blur: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder for album art
          Container(
            width: 160,
            height: 90,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.music_note,
                size: 30,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
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

/// Recently played card widget
class _RecentlyPlayedCard extends StatelessWidget {
  final String title;
  final String artist;
  final VoidCallback onTap;

  const _RecentlyPlayedCard({
    required this.title,
    required this.artist,
    required this.onTap,
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
          // Placeholder for album art
          Container(
            width: 100,
            height: 100,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.music_note,
                size: 30,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  artist,
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

/// Active download card widget
class _ActiveDownloadCard extends StatelessWidget {
  final DownloadTask task;

  const _ActiveDownloadCard({
    required this.task,
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
          // Placeholder for album art
          Container(
            width: 100,
            height: 80,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.download,
                size: 24,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
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
                  '${(task.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
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

/// Playlist card widget
class _PlaylistCard extends StatelessWidget {
  final String name;
  final int songCount;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.name,
    required this.songCount,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 120,
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
          // Placeholder for album art
          Container(
            width: 120,
            height: 80,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.playlist_play,
                size: 24,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  '$number Şarkı',
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