import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/localization.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/library_screen.dart';
import '../screens/settings_screen.dart';
import 'mini_player.dart';

/// The persistent application shell.
///
/// Mirrors SpotiFLAC's navigation model: a [NavigationBar] on phones and a
/// [NavigationRail] on wide/landscape layouts, a pinned [MiniPlayer] above the
/// bar, and a blurred backdrop. Feature screens live in an [IndexedStack] so
/// switching tabs never resets search text, library scroll, or home content.
const List<Widget> _pages = [
  HomeScreen(key: PageStorageKey('home')),
  SearchScreen(key: PageStorageKey('search')),
  LibraryScreen(key: PageStorageKey('library')),
  SettingsScreen(key: PageStorageKey('settings')),
];

const List<_ShellDestination> _destinations = [
  _ShellDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    labelKey: 'home',
  ),
  _ShellDestination(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    labelKey: 'search',
  ),
  _ShellDestination(
    icon: Icons.library_music_outlined,
    selectedIcon: Icons.library_music,
    labelKey: 'library',
  ),
  _ShellDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    labelKey: 'settings',
  ),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useRail = MediaQuery.sizeOf(context).width >= 600;

    final navBar = _ShellNavBar(
      currentIndex: _currentIndex,
      onSelected: _selectTab,
      useRail: useRail,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.scaffoldBackgroundColor,
              theme.colorScheme.secondary.withValues(alpha: 0.045),
            ],
          ),
        ),
        child: useRail
            ? Row(
                children: [
                  SafeArea(
                    right: false,
                    bottom: false,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height,
                        ),
                        child: IntrinsicHeight(
                          child: navBar,
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _Body(
                      currentIndex: _currentIndex,
                      pages: _pages,
                      miniPlayer: const MiniPlayer(),
                    ),
                  ),
                ],
              )
            : _Body(
                currentIndex: _currentIndex,
                pages: _pages,
                miniPlayer: const MiniPlayer(),
                bottomBar: navBar,
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.currentIndex,
    required this.pages,
    required this.miniPlayer,
    this.bottomBar,
  });

  final int currentIndex;
  final List<Widget> pages;
  final Widget miniPlayer;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IndexedStack(index: currentIndex, children: pages),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: (bottomBar != null ? 84 : 12) +
              MediaQuery.paddingOf(context).bottom,
          child: miniPlayer,
        ),
        if (bottomBar != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: bottomBar!,
          ),
      ],
    );
  }
}

class _ShellNavBar extends StatelessWidget {
  const _ShellNavBar({
    required this.currentIndex,
    required this.onSelected,
    required this.useRail,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool useRail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = List<NavigationDestination>.generate(
      _destinations.length,
      (i) {
        final d = _destinations[i];
        final selected = currentIndex == i;
        return NavigationDestination(
          icon: Icon(d.icon),
          selectedIcon: _AnimatedSelectedIcon(
            selected: selected,
            icon: d.selectedIcon,
          ),
          label: AppLocale.tr(d.labelKey),
        );
      },
    );

    if (useRail) {
      return NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        backgroundColor:
            theme.colorScheme.surfaceContainer.withValues(alpha: 0.72),
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationRailDestination(
              icon: Icon(_destinations[i].icon),
              selectedIcon: _AnimatedSelectedIcon(
                selected: currentIndex == i,
                icon: _destinations[i].selectedIcon,
              ),
              label: Text(AppLocale.tr(_destinations[i].labelKey)),
            ),
        ],
      );
    }

    final bar = NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      animationDuration: const Duration(milliseconds: 500),
      elevation: 0,
      height: 64,
      backgroundColor: theme.colorScheme.surfaceContainer.withValues(alpha: 0.72),
      destinations: destinations,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: bar,
        ),
      ),
    );
  }
}

/// Slight pop/rotation on the selected destination icon, echoing SpotiFLAC's
/// [BouncingIcon]/[SpinIcon] motion.
class _AnimatedSelectedIcon extends StatefulWidget {
  const _AnimatedSelectedIcon({required this.selected, required this.icon});

  final bool selected;
  final IconData icon;

  @override
  State<_AnimatedSelectedIcon> createState() => _AnimatedSelectedIconState();
}

class _AnimatedSelectedIconState extends State<_AnimatedSelectedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void didUpdateWidget(covariant _AnimatedSelectedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0, end: 0.125).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      ),
      child: Icon(widget.icon),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
}
