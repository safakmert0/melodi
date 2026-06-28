import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/library_screen.dart';
import 'mini_player.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: MelodiTheme.background.withOpacity(0.85),
                        border: Border(
                          top: BorderSide(
                            color: MelodiTheme.outlineVariant.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: BottomNavigationBar(
                          currentIndex: _currentIndex,
                          onTap: (index) => setState(() => _currentIndex = index),
                          selectedItemColor: MelodiTheme.primaryGreen,
                          unselectedItemColor: MelodiTheme.onSurfaceVariant,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          items: [
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.home_filled),
                              activeIcon: const Icon(Icons.home_filled),
                              label: AppLocale.tr('home'),
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.search_rounded),
                              activeIcon: const Icon(Icons.search_rounded),
                              label: AppLocale.tr('search'),
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.library_music_rounded),
                              activeIcon: const Icon(Icons.library_music_rounded),
                              label: AppLocale.tr('library'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
