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
import 'services/extension_service.dart';
import 'services/diagnostics_service.dart';
import 'services/crash_reporter.dart';
import 'services/logger_service.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/youtube_provider.dart';
import 'providers/mix_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/metadata_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/download_provider.dart';
import 'services/queue_manager.dart';
import 'services/resume_playback.dart';
import 'services/notification_service.dart';
import 'services/bluetooth_service.dart';
import 'services/audio_effects_service.dart';
import 'services/voice_control_service.dart';
import 'services/storage_manager.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/main_shell.dart';
import 'services/robust_piped_service.dart';
import 'services/hls_downloader_service.dart';

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
      await RobustPipedService.instance.initialize();
      AppLogger.i('RobustPipedService initialized');
    } catch (e) {
      AppLogger.e('RobustPipedService init failed: $e');
    }
    try {
      await HLSDownloaderService.instance.downloadHLS(
        hlsManifestUrl: '', // dummy to initialize
        videoId: 'init',
        title: '',
        artist: '',
      );
      AppLogger.i('HLSDownloaderService initialized');
    } catch (e) {
      AppLogger.e('HLSDownloaderService init failed: $e');
    }
    try {
      final migration = await StorageManager.instance.migrateLegacyDownloads();
      if (migration.moved > 0 || migration.relinked > 0) {
        AppLogger.i(
          'Private downloads migrated: ${migration.moved}, '
          'relinked: ${migration.relinked}',
        );
      }
    } catch (e) {
      AppLogger.e('Private download migration failed: $e');
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
                  Icon(Icons.error_outline,
                      color: MelodiTheme.errorRed, size: 48),
                  const SizedBox(height: 16),
                  Text('HATA:',
                      style: TextStyle(
                          color: MelodiTheme.errorRed,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${details.exception}',
                      style: TextStyle(
                          color: MelodiTheme.onSurface, fontSize: 12)),
                  const SizedBox(height: 16),
                  if (details.stack != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text('${details.stack}',
                            style: TextStyle(
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
              style: TextStyle(color: MelodiTheme.onSurface, fontSize: 16),
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
    _refreshExtensions();
  }

  /// Kurulu eklentileri depo sürümleriyle arka planda günceller; sunucu
  /// adresi değişirse (ör. tunnel yenilendiğinde) manifestler tazelenir.
  Future<void> _refreshExtensions() async {
    try {
      await ExtensionService.instance.updateAll();
    } catch (_) {}
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
      return Scaffold(
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
        ChangeNotifierProvider(create: (_) => MixProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => MetadataProvider(),
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
