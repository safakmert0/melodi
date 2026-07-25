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
  static const _dockHeight = 68.0;
  static const _horizontalInset = 14.0;

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
          gradient: RadialGradient(
            center: const Alignment(0.8, -1.1),
            radius: 1.25,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.11),
              theme.scaffoldBackgroundColor.withValues(alpha: 0),
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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 12),
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
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 23,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: selected
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
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
