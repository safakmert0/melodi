import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'core/constants.dart';
import 'core/localization.dart';
import 'services/audio_handler.dart';
import 'services/database_service.dart';
import 'services/diagnostics_service.dart';
import 'services/crash_reporter.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/youtube_provider.dart';
import 'providers/lastfm_provider.dart';
import 'services/ytmusic_service.dart';
import 'providers/ytmusic_provider.dart';
import 'providers/spotify_provider.dart';
import 'providers/mix_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/metadata_provider.dart';
import 'providers/scrobble_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/download_provider.dart';
import 'providers/like_mirror_provider.dart';
import 'services/scrobble_service.dart';
import 'services/like_mirror_service.dart';
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

    CrashReporter.init();
    DiagnosticsService.instance;

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
          create: (_) => ThemeProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = LastFmProvider();
            provider.loadSession();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final service = YTMusicService();
            final provider = YTMusicProvider(service);
            provider.loadSession();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => SpotifyProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final spotify = ctx.read<SpotifyProvider>();
            return MixProvider(spotifyService: spotify.service)..init();
          },
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => SyncProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final ytmusic = ctx.read<YTMusicProvider>();
            final spotify = ctx.read<SpotifyProvider>();
            final service = ScrobbleService(
              ytmusic: ytmusic.service,
              spotify: spotify.service,
            );
            final provider = ScrobbleProvider(service: service);
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final spotify = ctx.read<SpotifyProvider>();
            final ytmusic = ctx.read<YTMusicProvider>();
            final provider = ConnectionProvider(
              spotifyService: spotify.service,
              ytmusicService: ytmusic.service,
            );
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final spotify = ctx.read<SpotifyProvider>();
            final ytmusic = ctx.read<YTMusicProvider>();
            return MetadataProvider(
              spotifyService: spotify.service,
              ytmusicService: ytmusic.service,
            );
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final spotify = ctx.read<SpotifyProvider>();
            final ytmusic = ctx.read<YTMusicProvider>();
            final service = LikeMirrorService(
              spotifyService: spotify.service,
              ytMusicService: ytmusic.service,
            );
            final provider = LikeMirrorProvider(service);
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final player = context.read<PlayerProvider>();
          final lastfm = context.read<LastFmProvider>();
          player.onNowPlaying = () {
            final song = player.currentSong;
            if (song != null) {
              lastfm.updateNowPlaying(
                artist: song.artist,
                track: song.title,
                album: song.album,
              );
            }
          };
          player.onScrobble = (song, timestamp) {
            lastfm.scrobble(
              artist: song.artist,
              track: song.title,
              timestamp: timestamp,
              album: song.album,
            );
          };
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final pageTransitions = PageTransitionsTheme(
                builders: {
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                },
              );
              return MaterialApp(
                title: 'Melodi',
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme.copyWith(pageTransitionsTheme: pageTransitions),
                darkTheme: themeProvider.darkTheme.copyWith(pageTransitionsTheme: pageTransitions),
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
          );
        },
      ),
    );
  }
}
