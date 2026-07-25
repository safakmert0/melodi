import 'package:flutter/material.dart';

import '../../providers/connection_provider.dart';
import '../../screens/profile_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/source_hub_screen.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectedCount = [
      connection.spotifyConnected,
      connection.ytMusicConnected,
    ].where((connected) => connected).length;

    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: theme.colorScheme.onPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Melodi',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _HeaderButton(
          tooltip: connectedCount == 0
              ? 'Müzik kaynaklarını bağla'
              : '$connectedCount hesap bağlı',
          icon: connectedCount == 0 ? Icons.hub_outlined : Icons.hub_rounded,
          badge: connectedCount == 0 ? null : '$connectedCount',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SourceHubScreen()),
          ),
        ),
        const SizedBox(width: 4),
        _HeaderButton(
          tooltip: 'Ayarlar',
          icon: Icons.tune_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Geceye eşlik et';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'Tünaydın';
    return 'İyi akşamlar';
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 21),
        ),
        if (badge != null)
          Positioned(
            top: 1,
            right: 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
