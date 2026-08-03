import 'package:flutter/material.dart';

import '../../core/localization.dart';
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

    return SliverToBoxAdapter(
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderButton(
                      tooltip: connectedCount == 0
                          ? 'Müzik kaynaklarını bağla'
                          : '$connectedCount hesap bağlı',
                      icon: connectedCount == 0
                          ? Icons.hub_outlined
                          : Icons.hub_rounded,
                      badge: connectedCount == 0 ? null : '$connectedCount',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SourceHubScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Profil',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _HeaderButton(
                      tooltip: 'Ayarlar',
                      icon: Icons.settings_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _greeting(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _headline(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 31,
                    letterSpacing: -1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (AppLocale.currentLocale == 'en') {
      if (hour < 6) return 'LATE NIGHT';
      if (hour < 12) return 'GOOD MORNING';
      if (hour < 18) return 'GOOD AFTERNOON';
      return 'GOOD EVENING';
    }
    if (AppLocale.currentLocale == 'de') {
      if (hour < 6) return 'SPÄTE NACHT';
      if (hour < 12) return 'GUTEN MORGEN';
      if (hour < 18) return 'GUTEN TAG';
      return 'GUTEN ABEND';
    }
    if (hour < 6) return 'GECE MODU';
    if (hour < 12) return 'GÜNAYDIN';
    if (hour < 18) return 'TÜNAYDIN';
    return 'İYİ AKŞAMLAR';
  }

  static String _headline() {
    if (AppLocale.currentLocale == 'en') return 'What will move you?';
    if (AppLocale.currentLocale == 'de') return 'Was bewegt dich?';
    return 'Bugün ne dinleyeceksin?';
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
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 22),
        ),
        if (badge != null)
          Positioned(
            top: 5,
            right: 3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
