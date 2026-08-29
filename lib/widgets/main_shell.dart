import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/mini_player.dart';

/// Sade kabuk — LA Player gibi düz, blur ve ağır animasyon yok.
const List<Widget> _pages = [
  HomeScreen(key: PageStorageKey('home')),
  SearchScreen(key: PageStorageKey('search')),
  LibraryScreen(key: PageStorageKey('library')),
  SettingsScreen(key: PageStorageKey('settings')),
];

const List<_ShellDestination> _destinations = [
  _ShellDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, labelKey: 'home'),
  _ShellDestination(icon: Icons.search_outlined, selectedIcon: Icons.search, labelKey: 'search'),
  _ShellDestination(icon: Icons.library_music_outlined, selectedIcon: Icons.library_music, labelKey: 'library'),
  _ShellDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, labelKey: 'settings'),
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

    final destinations = List<NavigationDestination>.generate(
      _destinations.length,
      (i) {
        final d = _destinations[i];
        return NavigationDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: AppLocale.tr(d.labelKey),
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
                        label: Text(AppLocale.tr(d.labelKey)),
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
