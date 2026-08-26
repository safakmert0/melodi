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
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MelodiTheme.primaryGreen.withValues(alpha: 0.15),
                MelodiTheme.primaryGreen.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: context.tokens.borderRadiusCard,
            border: Border.all(
              color: MelodiTheme.primaryGreen.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MelodiTheme.primaryGreen.withValues(alpha: 0.3),
                      MelodiTheme.primaryGreen.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: MelodiTheme.primaryGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: MelodiTheme.primaryGreen,
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
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const LinearProgressIndicator(color: MelodiTheme.primaryGreen)
              else
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.play_circle_outline_rounded,
                        label: AppLocale.tr('total_plays'),
                        value: '$totalPlays',
                        color: MelodiTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.access_time_rounded,
                        label: AppLocale.tr('total_listening_time'),
                        value: '$totalMinutes ${AppLocale.tr('minutes')}',
                        color: const Color(0xFFFFA726),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.person_outline_rounded,
                        label: AppLocale.tr('unique_artists'),
                        value: '$uniqueArtists',
                        color: const Color(0xFFAB47BC),
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
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.music_note_rounded,
                      label: AppLocale.tr('songs'),
                      value: '$totalSongs',
                      color: MelodiTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.queue_music_rounded,
                      label: AppLocale.tr('playlists'),
                      value: '$totalPlaylists',
                      color: const Color(0xFF42A5F5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.favorite_rounded,
                      label: AppLocale.tr('liked_songs'),
                      value: '$favorites',
                      color: const Color(0xFFFF2D55),
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
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(context.tokens.radiusControl),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: MelodiTheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 12,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MelodiTheme.containerLow,
          borderRadius: context.tokens.borderRadiusCover,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 20, color: iconColor),
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
