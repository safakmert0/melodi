import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'core/constants.dart';
import 'services/audio_handler.dart';
import 'services/database_service.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBackground,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize database
  await DatabaseService.instance.database;

  // Initialize audio handler with service
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.melodi.channel',
      androidNotificationChannelName: 'Melodi Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: const Color(0xFF1DB954),
      fastForwardInterval: const Duration(seconds: 10),
      rewindInterval: const Duration(seconds: 10),
    ),
  );

  runApp(MelodiApp(audioHandler: audioHandler));
}

class MelodiApp extends StatelessWidget {
  final AudioPlayerHandler audioHandler;

  const MelodiApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlayerProvider(audioHandler),
        ),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider()..loadAll(),
        ),
        ChangeNotifierProvider(
          create: (_) => PlaylistProvider()..loadPlaylists(),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Melodi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
