import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'screens/now_playing_screen.dart';
import 'widgets/song_tile.dart';
import 'core/constants.dart';

// App-level utilities and helpers can be placed here
// The main application entry point is in main.dart

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/now-playing':
        return MaterialPageRoute(
          builder: (_) => const NowPlayingScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
