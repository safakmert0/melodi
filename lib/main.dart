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
import 'services/diagnostics_service.dart';
import 'services/crash_reporter.dart';
import 'services/logger_service.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/youtube_provider.dart';
import 'services/ytmusic_service.dart';
import 'providers/ytmusic_provider.dart';
import 'providers/spotify_provider.dart';
import 'providers/mix_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/metadata_provider.dart';
import 'providers/scrobble_provider.dart';
import 'providers/lastfm_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/download_provider.dart';
import 'providers/like_mirror_provider.dart';
import 'services/scrobble_service.dart';
import 'services/like_mirror_service.dart';
import 'services/queue_manager.dart';
import 'services/resume_playback.dart';
import 'services/notification_service.dart';
import 'services/bluetooth_service.dart';
import 'services/audio_effects_service.dart';
import 'services/voice_control_service.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: MelodiTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    try {
      CrashReporter.init();
    } catch (e) {
      AppLogger.e('CrashReporter init failed: $e');
    }
    try {
      DiagnosticsService.instance;
    } catch (e) {
      AppLogger.e('DiagnosticsService init failed: $e');
    }
    AppLogger.i('Melodi v${AppConstants.appVersion} starting...');

    final db = DatabaseService.instance;
    try {
      await db.database;
    } catch (e) {
      AppLogger.e('Database init failed: $e');
    }

    try {
      await NotificationService.instance.init();
    } catch (e) {
      AppLogger.e('NotificationService init failed: $e');
    }
    try {
      await AudioEffectsService().initialize();
    } catch (e) {
      AppLogger.e('AudioEffectsService init failed: $e');
    }
    try {
      BluetoothService.instance.detectBluetoothConnection();
    } catch (e) {
      AppLogger.e('BluetoothService init failed: $e');
    }
    try {
      VoiceControlService.instance.registerShortcuts();
    } catch (e) {
      AppLogger.e('VoiceControlService init failed: $e');
    }

    AppLogger.i('Services initialized');

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
          notificationColor: MelodiTheme.primaryGreen,
          fastForwardInterval: const Duration(seconds: 10),
          rewindInterval: const Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      audioHandler = AudioPlayerHandler();
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint(
          '=== FLUTTER ERROR ===\n${details.exceptionAsString()}\n${details.stack}');
    };

    ErrorWidget.builder = (details) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: MelodiTheme.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: MelodiTheme.errorRed, size: 48),
                  const SizedBox(height: 16),
                  const Text('HATA:',
                      style: TextStyle(
                          color: MelodiTheme.errorRed,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${details.exception}',
                      style: const TextStyle(
                          color: MelodiTheme.onSurface, fontSize: 12)),
                  const SizedBox(height: 16),
                  if (details.stack != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text('${details.stack}',
                            style: const TextStyle(
                                color: MelodiTheme.onSurfaceVariant,
                                fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    runZonedGuarded(() {
      runApp(MelodiApp(audioHandler: audioHandler));
    }, (error, stack) {
      debugPrint('=== UNCAUGHT ERROR ===\n$error\n$stack');
    });
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: MelodiTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Startup error:\n$e',
              style:
                  const TextStyle(color: MelodiTheme.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _loading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final db = DatabaseService.instance;
      final value = await db.getSetting('onboarding_completed');
      if (!mounted) return;
      setState(() {
        _showOnboarding = value != 'true';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showOnboarding = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: MelodiTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: MelodiTheme.primaryGreen),
        ),
      );
    }
    return _showOnboarding ? const OnboardingScreen() : const MainShell();
  }
}

class MelodiApp extends StatelessWidget {
  final AudioPlayerHandler audioHandler;

  const MelodiApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider(audioHandler)),
        ChangeNotifierProvider(create: (_) => LibraryProvider()..loadAll()),
        ChangeNotifierProvider(
            create: (_) => PlaylistProvider()..loadPlaylists()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => YouTubeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleNotifier()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => SpotifyProvider()..init()),
        ChangeNotifierProvider(create: (_) {
          final service = YTMusicService();
          return YTMusicProvider(service)..loadSession();
        }),
        ChangeNotifierProvider(
          create: (ctx) {
            final spotify = ctx.read<SpotifyProvider>();
            return MixProvider(spotifyService: spotify.service)..init();
          },
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(
          create: (ctx) {
            final sync = SyncProvider();
            final spotify = ctx.read<SpotifyProvider>();
            final ytmusic = ctx.read<YTMusicProvider>();
            sync.setServices(
                spotify: spotify.service, ytmusic: ytmusic.service);
            // Delay sync init to allow SpotifyProvider/YTMusicProvider to finish loading
            Future.delayed(const Duration(seconds: 5), () {
              if (spotify.isConnected || ytmusic.isConnected) {
                sync.triggerSync();
              }
            });
            return sync;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final ytmusic = ctx.read<YTMusicProvider>();
            final spotify = ctx.read<SpotifyProvider>();
            final service = ScrobbleService(
                ytmusic: ytmusic.service, spotify: spotify.service);
            final provider = ScrobbleProvider(service: service);
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => LastFmProvider()..loadSession()),
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
                ytmusicService: ytmusic.service);
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final spotify = ctx.read<SpotifyProvider>();
            final ytmusic = ctx.read<YTMusicProvider>();
            final service = LikeMirrorService(
                spotifyService: spotify.service,
                ytMusicService: ytmusic.service);
            final provider = LikeMirrorProvider(service);
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final dp = DownloadProvider();
            dp.setLibraryProvider(ctx.read<LibraryProvider>());
            return dp;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final qm = QueueManager();
            qm.restoreQueue();
            return qm;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final rp = ResumePlayback();
            rp.restorePlaybackState();
            return rp;
          },
        ),
      ],
      child: Consumer2<ThemeProvider, LocaleNotifier>(
        builder: (context, themeProvider, localeNotifier, _) {
          return MaterialApp(
            title: 'Melodi',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: Locale(localeNotifier.locale),
            home: const _AppEntry(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('tr'), Locale('de')],
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
