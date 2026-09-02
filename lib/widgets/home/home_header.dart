import 'package:flutter/material.dart';

import '../../core/localization.dart';
import '../../screens/profile_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/source_hub_screen.dart';
import '../../screens/search_screen.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SliverToBoxAdapter(
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderButton(
                      tooltip: 'Müzik kaynaklarını bağla',
                      icon: Icons.hub_outlined,
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
                            color: scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _HeaderButton(
                      tooltip: 'Ara',
                      icon: Icons.search_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SearchScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                const SizedBox(height: 16),
                Text(
                  _greeting(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _headline(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
