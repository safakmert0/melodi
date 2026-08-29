import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../theme/app_tokens.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/listening_recorder.dart';
import '../core/melodi_design.dart';
import '../widgets/listening_heatmap.dart';
import 'settings_screen.dart';
import 'downloads_screen.dart';
import 'library_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _listeningStats = {};
  List<Map<String, dynamic>> _listeningDays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final recorder = ListeningRecorder.instance;
      final results = await Future.wait([
        recorder.getListeningStats(),
        recorder.getListeningHistoryGroupedByDate(limitDays: 190),
      ]);
      final stats = results[0] as Map<String, dynamic>;
      final listeningDays = results[1] as List<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _listeningStats = stats;
          _listeningDays = listeningDays;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: MelodiTheme.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              AppLocale.tr('settings'),
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_rounded,
                    color: MelodiTheme.onSurfaceVariant),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
            floating: true,
            pinned: false,
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Card
                _buildProfileCard(),
                const SizedBox(height: 24),
                // Listening Stats
                _buildListeningStats(),
                const SizedBox(height: 24),
                // Quick Actions
                _buildQuickActions(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainerHighest,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Melodi Kullanıcısı',
                      style: TextStyle(
                        color: MelodiTheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.tr('listening_stats'),
                      style: TextStyle(
                        color: MelodiTheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: MelodiTheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListeningStats() {
    return Consumer2<LibraryProvider, PlaylistProvider>(
      builder: (context, library, playlists, _) {
        final totalSongs = library.songs.length;
        final totalPlaylists = playlists.playlists.length;
        final favorites = library.favorites.length;
        final totalPlays = _listeningStats['totalPlays'] as int? ?? 0;
        final totalMinutes =
            ((_listeningStats['totalListeningTimeMs'] as int? ?? 0) / 60000)
                .round();
        final uniqueArtists = _listeningStats['uniqueArtists'] as int? ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocale.tr('listening_stats').toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                LinearProgressIndicator(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)
              else
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.play_circle_outline_rounded,
                        label: AppLocale.tr('total_plays'),
                        value: '$totalPlays',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.access_time_rounded,
                        label: AppLocale.tr('total_listening_time'),
                        value: '$totalMinutes ${AppLocale.tr('minutes')}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.person_outline_rounded,
                        label: AppLocale.tr('unique_artists'),
                        value: '$uniqueArtists',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              MelodiPanel(
                child: ListeningHeatmap(days: _listeningDays),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocale.tr('library').toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.music_note_rounded,
                      label: AppLocale.tr('songs'),
                      value: '$totalSongs',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.queue_music_rounded,
                      label: AppLocale.tr('playlists'),
                      value: '$totalPlaylists',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.favorite_rounded,
                      label: AppLocale.tr('liked_songs'),
                      value: '$favorites',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.tr('quick_access'),
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _QuickActionTile(
            icon: Icons.history_rounded,
            iconColor: Colors.orange,
            title: AppLocale.tr('recently_played'),
            subtitle: AppLocale.tr('recently_played_subtitle'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          _QuickActionTile(
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFFF2D55),
            title: AppLocale.tr('liked_songs'),
            subtitle: AppLocale.tr('liked_songs_subtitle'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          _QuickActionTile(
            icon: Icons.download_rounded,
            iconColor: Colors.green,
            title: AppLocale.tr('downloads'),
            subtitle: AppLocale.tr('downloads_subtitle'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerHighest,
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Icon(icon, size: 18, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: MelodiTheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: MelodiTheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
