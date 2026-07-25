import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import 'mini_player.dart';

/// The persistent application shell.
///
/// Feature screens intentionally live in an [IndexedStack] so switching tabs
/// never resets search text, library scroll position, or loaded home content.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _dockHeight = 74.0;
  static const _horizontalInset = 12.0;

  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(key: PageStorageKey('home')),
    SearchScreen(key: PageStorageKey('search')),
    LibraryScreen(key: PageStorageKey('library')),
  ];

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

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
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
            Positioned(
              left: _horizontalInset,
              right: _horizontalInset,
              bottom: bottomSafeArea + _dockHeight + 14,
              child: const MiniPlayer(),
            ),
            Positioned(
              left: _horizontalInset,
              right: _horizontalInset,
              bottom: bottomSafeArea + 8,
              child: _MelodiDock(
                currentIndex: _currentIndex,
                onSelected: _selectTab,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MelodiDock extends StatelessWidget {
  const _MelodiDock({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      _DockItemData(
        icon: Icons.home_rounded,
        label: AppLocale.tr('home'),
      ),
      _DockItemData(
        icon: Icons.search_rounded,
        label: AppLocale.tr('search'),
      ),
      _DockItemData(
        icon: Icons.library_music_rounded,
        label: AppLocale.tr('library'),
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 74,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.3 : 0.13,
                ),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final selected = currentIndex == index;
              final item = items[index];
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: item.label,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: selected ? 24 : 22,
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DockItemData {
  const _DockItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
