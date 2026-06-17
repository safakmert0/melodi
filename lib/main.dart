import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'core/constants.dart';
import 'core/localization.dart';
import 'services/audio_handler.dart';
import 'services/database_service.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/youtube_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: const Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    final db = DatabaseService.instance;
    await db.database;

    final savedLocale = await db.getSetting('app_locale');
    if (savedLocale != null && savedLocale.isNotEmpty) {
      AppLocale.currentLocale = savedLocale;
    } else {
      AppLocale.currentLocale = 'tr';
    }

    late final AudioPlayerHandler audioHandler;
    try {
      audioHandler = await AudioService.init(
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
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      audioHandler = AudioPlayerHandler();
    }

    ErrorWidget.builder = (details) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Build Error:',
                    style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      '${details.exception}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    };

    runApp(MelodiApp(audioHandler: audioHandler));
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Startup error:\n$e',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
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
        ChangeNotifierProvider(
          create: (_) => YouTubeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Melodi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('tr'),
              Locale('de'),
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale != null) {
                for (final supported in supportedLocales) {
                  if (supported.languageCode == locale.languageCode) {
                    return supported;
                  }
                }
              }
              return const Locale('en');
            },
          );
        },
      ),
    );
  }
}
