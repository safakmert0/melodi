import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/mini_player.dart';

/// Basla / Kesif / Kaydedilenler / Ayarlar + MiniPlayer.
/// Klasor izleme Ayarlar > Izlenen Klasorler'den yonetilir (kopyasiz izleme).
const List<Widget> _pages = [
  HomeScreen(key: PageStorageKey('home')),
  SearchScreen(key: PageStorageKey('search')),
  LibraryScreen(key: PageStorageKey('library')),
  SettingsScreen(key: PageStorageKey('settings')),
];

const List<_ShellDestination> _destinations = [
  _ShellDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, labelKey: 'basla'),
  _ShellDestination(icon: Icons.search_outlined, selectedIcon: Icons.search, labelKey: 'kesif'),
  _ShellDestination(icon: Icons.library_music_outlined, selectedIcon: Icons.library_music, labelKey: 'kaydedilenler'),
  _ShellDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, labelKey: 'ayarlar'),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useRail = MediaQuery.sizeOf(context).width >= 600;

    String labelFor(String key) {
      final locale = AppLocale.currentLocale;
      switch (key) {
        case 'basla':
          if (locale == 'de') return 'Start';
          if (locale == 'en') return 'Home';
          return 'Başla';
        case 'kesif':
          if (locale == 'de') return 'Entdecken';
          if (locale == 'en') return 'Explore';
          return 'Keşif';
        case 'kaydedilenler':
          if (locale == 'de') return 'Gespeichert';
          if (locale == 'en') return 'Saved';
          return 'Kaydedilenler';
        case 'ayarlar':
          if (locale == 'de') return 'Einstellungen';
          if (locale == 'en') return 'Settings';
          return 'Ayarlar';
        case 'files':
          if (locale == 'tr') return 'Dosyalar';
          if (locale == 'de') return 'Dateien';
          return 'Files';
        default:
          return AppLocale.tr(key);
      }
    }

    final destinations = List<NavigationDestination>.generate(
      _destinations.length,
      (i) {
        final d = _destinations[i];
        return NavigationDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: labelFor(d.labelKey),
        );
      },
    );

    final pageView = IndexedStack(index: _currentIndex, children: _pages);

    final bottomBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniPlayer(),
        if (!useRail)
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onNavTap,
            elevation: 0,
            height: 64,
            backgroundColor: theme.colorScheme.surface,
            destinations: destinations,
          ),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onNavTap,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.colorScheme.surface,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(labelFor(d.labelKey)),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pageView),
              ],
            )
          : pageView,
      bottomNavigationBar: bottomBar,
    );
  }
}

class _ShellDestination {
  const _ShellDestination({required this.icon, required this.selectedIcon, required this.labelKey});
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
}
