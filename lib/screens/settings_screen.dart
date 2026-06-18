import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/lastfm_provider.dart';
import '../providers/ytmusic_provider.dart';
import '../providers/spotify_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _localeName(AppLocale.currentLocale);
    _loadWatchedFolder();
    _loadPlaybackSettings();
  }

  Future<void> _loadPlaybackSettings() async {
    final db = DatabaseService.instance;
    final crossfade = await db.getSetting('crossfade_seconds');
    final shuffle = await db.getSetting('auto_shuffle');
    final gapless = await db.getSetting('gapless_playback');
    if (mounted) {
      setState(() {
        _crossfadeSeconds = double.tryParse(crossfade ?? '') ?? 0;
        _autoShuffle = shuffle == 'true';
        _gaplessPlayback = gapless != 'false';
      });
    }
  }

  String _localeName(String code) {
    switch (code) {
      case 'tr': return AppLocale.tr('turkish');
      case 'de': return AppLocale.tr('german');
      default: return AppLocale.tr('english');
    }
  }
  double _crossfadeSeconds = 0;
  bool _autoShuffle = false;
  bool _gaplessPlayback = true;
  String _watchedFolderPath = '';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _loadWatchedFolder() async {
    final path = await context.read<LibraryProvider>().getWatchedFolder();
    if (mounted) setState(() => _watchedFolderPath = path ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LibraryProvider, PlayerProvider, LocaleNotifier>(
      builder: (context, library, player, locale, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: Text(
                AppLocale.tr('settings'),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              floating: true,
              pinned: false,
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(AppLocale.tr('general')),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.teal,
                    title: AppLocale.tr('app_language'),
                    subtitle: _selectedLanguage,
                    trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => _showLanguagePicker(context),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.amber,
                    title: AppLocale.tr('theme'),
                    subtitle: Consumer<ThemeProvider>(
                      builder: (context, tp, _) => Text(
                        tp.isDark ? AppLocale.tr('dark') : tp.isLight ? AppLocale.tr('light') : AppLocale.tr('system'),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => _AppearanceSettingsPage()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.play_circle_outline,
                    iconColor: Colors.amber,
                    title: AppLocale.tr('playback'),
                    subtitle: AppLocale.tr('gapless_playback'),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => _PlaybackSettingsPage(
                        crossfadeSeconds: _crossfadeSeconds,
                        autoShuffle: _autoShuffle,
                        gaplessPlayback: _gaplessPlayback,
                        onCrossfadeChanged: (v) => setState(() => _crossfadeSeconds = v),
                        onAutoShuffleChanged: (v) => setState(() => _autoShuffle = v),
                        onGaplessChanged: (v) => setState(() => _gaplessPlayback = v),
                      )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('music_library')),
                  _SettingsTile(
                    icon: Icons.refresh_rounded,
                    iconColor: AppTheme.primaryColor,
                    title: AppLocale.tr('rescan_library'),
                    subtitle: AppLocale.tr('scan_device_for_music'),
                    trailing: library.isScanning
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                          )
                        : null,
                    onTap: () => library.scanMusic(),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.folder_open_rounded,
                    iconColor: Colors.orange,
                    title: AppLocale.tr('import_from_files'),
                    subtitle: AppLocale.tr('browse_and_import'),
                    onTap: () => library.importFromFiles(),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.folder_special_rounded,
                    iconColor: Colors.purple,
                    title: AppLocale.tr('import_from_folder_title'),
                    subtitle: AppLocale.tr('scan_folder_for_music'),
                    onTap: () => library.importFromDirectory(),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.folder_rounded,
                    iconColor: Colors.deepPurple,
                    title: AppLocale.tr('watched_folder'),
                    subtitle: _watchedFolderPath.isNotEmpty
                        ? '${AppLocale.tr('watching')}: $_watchedFolderPath'
                        : AppLocale.tr('auto_scan_folder'),
                    trailing: _watchedFolderPath.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: AppTheme.textTertiary, size: 18),
                            onPressed: () async {
                              await library.clearWatchedFolder();
                              setState(() => _watchedFolderPath = '');
                            },
                          )
                        : null,
                    onTap: () => _pickWatchedFolder(context),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('storage')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.storage_rounded, color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocale.tr('local_songs'),
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                              Text(
                                '${library.songCount} ${AppLocale.tr('songs_in_library')} · ${_formatBytes(library.totalSongSizeBytes)}',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.delete_sweep_rounded,
                    iconColor: AppTheme.errorColor,
                    title: AppLocale.tr('clear_library'),
                    subtitle: AppLocale.tr('remove_cached_data'),
                    onTap: () => _confirmClearLibrary(context),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('accounts')),
                  // Last.fm
                  Consumer<LastFmProvider>(
                    builder: (context, lastfm, _) {
                      if (lastfm.isConnected) {
                        return _SettingsTile(
                          icon: Icons.radio_rounded,
                          iconColor: Colors.red,
                          title: 'Last.fm',
                          subtitle: '${AppLocale.tr('connected_as')} ${lastfm.username}',
                          trailing: TextButton(
                            onPressed: () => lastfm.disconnect(),
                            child: Text(AppLocale.tr('disconnect'),
                                style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const _LastFmSettingsPage()),
                          ),
                        );
                      }
                      return _SettingsTile(
                        icon: Icons.radio_rounded,
                        iconColor: Colors.red,
                        title: 'Last.fm',
                        subtitle: AppLocale.tr('connect_for_scrobbling'),
                        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _LastFmSettingsPage()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Consumer<SpotifyProvider>(
                    builder: (context, spotify, _) {
                      if (spotify.isConnected) {
                        return _SettingsTile(
                          icon: Icons.music_video_rounded,
                          iconColor: Colors.green,
                          title: AppLocale.tr('spotify'),
                          subtitle: '${AppLocale.tr('spotify_connected_as')} ${spotify.username}',
                          trailing: TextButton(
                            onPressed: () => spotify.disconnect(),
                            child: Text(AppLocale.tr('disconnect'),
                                style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const _SpotifySettingsPage()),
                          ),
                        );
                      }
                      return _SettingsTile(
                        icon: Icons.music_video_rounded,
                        iconColor: Colors.green,
                        title: AppLocale.tr('spotify'),
                        subtitle: AppLocale.tr('connect_spotify_description'),
                        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _SpotifySettingsPage()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Consumer<YTMusicProvider>(
                    builder: (context, ytmusic, _) {
                      if (ytmusic.isConnected) {
                        return _SettingsTile(
                          icon: Icons.play_circle_filled_rounded,
                          iconColor: Colors.red,
                          title: AppLocale.tr('youtube_music'),
                          subtitle: AppLocale.tr('connected_as'),
                          trailing: TextButton(
                            onPressed: () => ytmusic.disconnect(),
                            child: Text(AppLocale.tr('disconnect'),
                                style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const _YtMusicSettingsPage()),
                          ),
                        );
                      }
                      return _SettingsTile(
                        icon: Icons.play_circle_filled_rounded,
                        iconColor: Colors.red,
                        title: AppLocale.tr('youtube_music'),
                        subtitle: AppLocale.tr('connect_youtube_music'),
                        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _YtMusicSettingsPage()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('audio')),
                  _SettingsTile(
                    icon: Icons.tune_rounded,
                    iconColor: Colors.purple,
                    title: AppLocale.tr('equalizer'),
                    subtitle: AppLocale.tr('adjust_sound_frequencies'),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _EqualizerPage()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('streaming')),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) => _SettingsTile(
                      icon: Icons.cloud_rounded,
                      iconColor: Colors.lightBlue,
                      title: AppLocale.tr('streaming'),
                      subtitle: settings.streamingEnabled
                          ? AppLocale.tr('online_mode')
                          : AppLocale.tr('offline_mode'),
                      trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _StreamingSettingsPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.sync_rounded,
                    iconColor: Colors.teal,
                    title: AppLocale.tr('auto_sync'),
                    subtitle: AppLocale.tr('sync_schedule'),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _SyncSettingsPage()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('developer')),
                  _SettingsTile(
                    icon: Icons.code_rounded,
                    iconColor: Colors.grey,
                    title: 'GitHub',
                    subtitle: 'safakmert0',
                    onTap: () => _openUrl('https://github.com/safakmert0'),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.send_rounded,
                    iconColor: Colors.lightBlue,
                    title: 'Telegram',
                    subtitle: '@safakmert',
                    onTap: () => _openUrl('https://t.me/safakmert'),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppTheme.divider, height: 1),
                  _SectionTitle(AppLocale.tr('about')),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.textSecondary,
                    title: 'Melodi',
                    subtitle: '${AppLocale.tr('version')} ${AppConstants.appVersion}',
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.favorite_rounded,
                    iconColor: AppTheme.favoriteColor,
                    title: AppLocale.tr('credits'),
                    subtitle: AppLocale.tr('open_source_licenses'),
                    onTap: () => _showCredits(context),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('theme'),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.dark_mode_rounded, color: themeProvider.isDark ? AppTheme.primaryColor : AppTheme.textTertiary),
              title: Text(AppLocale.tr('dark'), style: TextStyle(color: AppTheme.textPrimary)),
              trailing: themeProvider.isDark ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.light_mode_rounded, color: themeProvider.isLight ? AppTheme.primaryColor : AppTheme.textTertiary),
              title: Text(AppLocale.tr('light'), style: TextStyle(color: AppTheme.textPrimary)),
              trailing: themeProvider.isLight ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_brightness_rounded, color: themeProvider.isSystem ? AppTheme.primaryColor : AppTheme.textTertiary),
              title: Text(AppLocale.tr('system'), style: TextStyle(color: AppTheme.textPrimary)),
              trailing: themeProvider.isSystem ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // (moved to top level)

  void _showAccentColorPicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('accent_color'),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _accentColors.map((color) {
                  final isSelected = themeProvider.accentColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setAccentColor(color);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.black, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('app_language'),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...[
              (AppLocale.tr('english'), 'en'),
              (AppLocale.tr('turkish'), 'tr'),
              (AppLocale.tr('german'), 'de'),
            ].map((entry) {
              return ListTile(
                title: Text(entry.$1,
                    style: TextStyle(color: AppTheme.textPrimary)),
                trailing: _selectedLanguage == entry.$1
                    ? Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedLanguage = entry.$1;
                    AppLocale.change(entry.$2);
                    context.read<LocaleNotifier>().change(entry.$2);
                    DatabaseService.instance.setSetting('app_locale', entry.$2);
                  });
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCrossfadeSlider(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        double localCrossfade = _crossfadeSeconds;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(AppLocale.tr('crossfade'),
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${localCrossfade.toInt()} ${AppLocale.tr('seconds')}',
                      style: TextStyle(
                          color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  Slider(
                    value: localCrossfade,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: AppTheme.divider,
                    onChanged: (v) {
                      setSheetState(() => localCrossfade = v);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocale.tr('off'),
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                      Text('12s',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _crossfadeSeconds = localCrossfade);
                        player.setCrossfade(Duration(seconds: localCrossfade.toInt()));
                        DatabaseService.instance.setSetting('crossfade_seconds', localCrossfade.toString());
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(AppLocale.tr('apply')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCredits(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Melodi',
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 32),
      ),
      applicationLegalese: 'Built with Flutter & Love',
    );
  }

  Future<void> _pickWatchedFolder(BuildContext context) async {
    final lib = context.read<LibraryProvider>();
    String? selectedDirectory;

    if (Platform.isIOS) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: const [
          'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma',
          'alac', 'aiff', 'opus', 'ape', 'wv',
        ],
      );
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final firstPath = result.files.first.path!;
        selectedDirectory = firstPath.substring(0, firstPath.lastIndexOf('/'));
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
        if (paths.isNotEmpty) {
          await lib.importFromFilePaths(paths);
        }
      }
    } else {
      try {
        selectedDirectory = await FilePicker.platform.getDirectoryPath();
      } catch (_) {
        // Fallback to file picker on platforms where getDirectoryPath is not supported
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowMultiple: true,
          allowedExtensions: const [
            'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma',
            'alac', 'aiff', 'opus', 'ape', 'wv',
          ],
        );
        if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
          final firstPath = result.files.first.path!;
          selectedDirectory = firstPath.substring(0, firstPath.lastIndexOf('/'));
          final paths = result.files
              .where((f) => f.path != null)
              .map((f) => f.path!)
              .toList();
          if (paths.isNotEmpty) {
            await lib.importFromFilePaths(paths);
          }
        }
      }
    }

    final dir = selectedDirectory;
    if (dir != null && dir.isNotEmpty) {
      await lib.setWatchedFolder(dir);
      setState(() => _watchedFolderPath = dir);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocale.tr('watching')}: $dir'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('could_not_open_link')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _confirmClearLibrary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocale.tr('clear_library_title'),
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          AppLocale.tr('clear_library_confirm'),
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<LibraryProvider>().clearLibrary();
              Navigator.pop(context);
            },
            child: Text(AppLocale.tr('delete'),
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('appearance')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SectionTitle(AppLocale.tr('theme_mode')),
              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.amber,
                title: AppLocale.tr('theme'),
                subtitle: themeProvider.isDark
                    ? AppLocale.tr('dark')
                    : themeProvider.isLight
                        ? AppLocale.tr('light')
                        : AppLocale.tr('system'),
                trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                onTap: () => _showThemePicker(context, themeProvider),
              ),
              const SizedBox(height: 16),
              _SectionTitle(AppLocale.tr('accent_color')),
              const SizedBox(height: 8),
              ...(_accentColors.map((c) {
                final isSelected = themeProvider.accentColor.value == c.value;
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black, size: 16)
                        : null,
                  ),
                  title: Text(
                    _accentColorName(c),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20)
                      : null,
                  onTap: () => themeProvider.setAccentColor(c),
                );
              })),
              const SizedBox(height: 16),
              _SectionTitle(AppLocale.tr('custom_colors')),
              _CustomColorTile(
                label: AppLocale.tr('background'),
                icon: Icons.wallpaper_rounded,
                currentColor: themeProvider.customBackground,
                defaultColor: AppTheme.isLightMode ? AppTheme.lightBackground : AppTheme.darkBackground,
                onChanged: (c) => themeProvider.setCustomBackground(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('surface'),
                icon: Icons.square_rounded,
                currentColor: themeProvider.customSurface,
                defaultColor: AppTheme.isLightMode ? AppTheme.lightSurface : AppTheme.darkSurface,
                onChanged: (c) => themeProvider.setCustomSurface(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('card'),
                icon: Icons.crop_square_rounded,
                currentColor: themeProvider.customCard,
                defaultColor: AppTheme.isLightMode ? AppTheme.lightCard : AppTheme.darkCard,
                onChanged: (c) => themeProvider.setCustomCard(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('text_primary'),
                icon: Icons.text_fields_rounded,
                currentColor: themeProvider.customTextPrimary,
                defaultColor: AppTheme.isLightMode ? const Color(0xFF1A1A1A) : Colors.white,
                onChanged: (c) => themeProvider.setCustomTextPrimary(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('text_secondary'),
                icon: Icons.text_fields_rounded,
                currentColor: themeProvider.customTextSecondary,
                defaultColor: AppTheme.isLightMode ? const Color(0xFF666666) : const Color(0xFFB3B3B3),
                onChanged: (c) => themeProvider.setCustomTextSecondary(c),
              ),
              if (themeProvider.customBackground != null ||
                  themeProvider.customSurface != null ||
                  themeProvider.customCard != null ||
                  themeProvider.customTextPrimary != null ||
                  themeProvider.customTextSecondary != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () => themeProvider.resetCustomColors(),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(AppLocale.tr('reset_colors')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _accentColorName(Color c) {
    const names = {
      0xFF1DB954: 'Spotify Green',
      0xFF1ED760: 'Green',
      0xFFFA233B: 'Red',
      0xFFFF2D55: 'Pink',
      0xFF007AFF: 'Blue',
      0xFF5856D6: 'Indigo',
      0xFFAF52DE: 'Purple',
      0xFFFF9500: 'Orange',
      0xFFFFCC02: 'Yellow',
      0xFF34C759: 'Mint',
      0xFF00C7BE: 'Teal',
      0xFFFFFFFF: 'White',
      0xFFE91E63: 'Rose',
      0xFF9C27B0: 'Deep Purple',
      0xFF2196F3: 'Light Blue',
      0xFF00BCD4: 'Cyan',
      0xFF4CAF50: 'Material Green',
      0xFFFF5722: 'Deep Orange',
      0xFF795548: 'Brown',
      0xFF607D8B: 'Blue Grey',
    };
    return names[c.value] ?? '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _showThemePicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(AppLocale.tr('theme'),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _themeOption(ctx, themeProvider, AppLocale.tr('system'), null),
              _themeOption(ctx, themeProvider, AppLocale.tr('light'), false),
              _themeOption(ctx, themeProvider, AppLocale.tr('dark'), true),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, ThemeProvider themeProvider, String label, bool? isDark) {
    final selected = themeProvider.isDark == isDark;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppTheme.primaryColor : AppTheme.textTertiary,
      ),
      title: Text(label, style: TextStyle(color: AppTheme.textPrimary)),
      onTap: () {
        if (isDark == null) {
          themeProvider.setThemeMode(ThemeMode.system);
        } else if (isDark) {
          themeProvider.setThemeMode(ThemeMode.dark);
        } else {
          themeProvider.setThemeMode(ThemeMode.light);
        }
        Navigator.pop(ctx);
      },
    );
  }
}

class _PlaybackSettingsPage extends StatefulWidget {
  final double crossfadeSeconds;
  final bool autoShuffle;
  final bool gaplessPlayback;
  final ValueChanged<double> onCrossfadeChanged;
  final ValueChanged<bool> onAutoShuffleChanged;
  final ValueChanged<bool> onGaplessChanged;

  const _PlaybackSettingsPage({
    required this.crossfadeSeconds,
    required this.autoShuffle,
    required this.gaplessPlayback,
    required this.onCrossfadeChanged,
    required this.onAutoShuffleChanged,
    required this.onGaplessChanged,
  });

  @override
  State<_PlaybackSettingsPage> createState() => _PlaybackSettingsPageState();
}

class _PlaybackSettingsPageState extends State<_PlaybackSettingsPage> {
  late double _crossfade;

  @override
  void initState() {
    super.initState();
    _crossfade = widget.crossfadeSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('playback')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsTile(
            icon: Icons.shuffle_rounded,
            iconColor: Colors.amber,
            title: AppLocale.tr('auto_shuffle'),
            subtitle: AppLocale.tr('automatically_shuffle'),
            trailing: Switch(
              value: widget.autoShuffle,
              onChanged: (v) {
                widget.onAutoShuffleChanged(v);
                player.setAutoShuffle(v);
                DatabaseService.instance.setSetting('auto_shuffle', v.toString());
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () {
              final v = !widget.autoShuffle;
              widget.onAutoShuffleChanged(v);
              player.setAutoShuffle(v);
              DatabaseService.instance.setSetting('auto_shuffle', v.toString());
            },
          ),
          _SettingsTile(
            icon: Icons.waves_rounded,
            iconColor: Colors.pink,
            title: AppLocale.tr('gapless_playback'),
            subtitle: AppLocale.tr('seamless_transition'),
            trailing: Switch(
              value: widget.gaplessPlayback,
              onChanged: (v) {
                widget.onGaplessChanged(v);
                player.setGaplessPlayback(v);
                DatabaseService.instance.setSetting('gapless_playback', v.toString());
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () {
              final v = !widget.gaplessPlayback;
              widget.onGaplessChanged(v);
              player.setGaplessPlayback(v);
              DatabaseService.instance.setSetting('gapless_playback', v.toString());
            },
          ),
          _SettingsTile(
            icon: Icons.swap_horiz_rounded,
            iconColor: Colors.indigo,
            title: AppLocale.tr('crossfade'),
            subtitle: '${_crossfade.toInt()} ${AppLocale.tr('seconds_crossfade')}',
            trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            onTap: () => _showCrossfadeSlider(context),
          ),
        ],
      ),
    );
  }

  void _showCrossfadeSlider(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppLocale.tr('crossfade'),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${_crossfade.toInt()} ${AppLocale.tr('seconds_crossfade')}',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _crossfade,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: AppTheme.textTertiary,
                  onChanged: (v) => setSheetState(() => _crossfade = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child:                   ElevatedButton(
                    onPressed: () {
                      widget.onCrossfadeChanged(_crossfade);
                      final player = context.read<PlayerProvider>();
                      player.setCrossfade(Duration(seconds: _crossfade.toInt()));
                      DatabaseService.instance.setSetting('crossfade_seconds', _crossfade.toInt().toString());
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(AppLocale.tr('apply')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastFmSettingsPage extends StatefulWidget {
  const _LastFmSettingsPage();

  @override
  State<_LastFmSettingsPage> createState() => _LastFmSettingsPageState();
}

class _LastFmSettingsPageState extends State<_LastFmSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Last.fm'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Consumer<LastFmProvider>(
        builder: (context, lastfm, _) {
          if (lastfm.isConnected) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsTile(
                  icon: Icons.person_rounded,
                  iconColor: Colors.red,
                  title: '${AppLocale.tr('connected_as')} ${lastfm.username}',
                  subtitle: AppLocale.tr('scrobbling_enabled'),
                  trailing: TextButton(
                    onPressed: () async {
                      await lastfm.disconnect();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppLocale.tr('disconnect'),
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppLocale.tr('lastfm_description'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (lastfm.isConnecting)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await lastfm.startAuth();
                      if (context.mounted && lastfm.error == null) {
                        _openAuthUrl(context, lastfm);
                      }
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: Text(AppLocale.tr('connect_lastfm')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              if (lastfm.error != null) ...[
                const SizedBox(height: 16),
                Text(lastfm.error!, style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openAuthUrl(BuildContext context, LastFmProvider lastfm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocale.tr('authorize_lastfm'),
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          AppLocale.tr('lastfm_auth_instructions'),
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pollForSession(context, lastfm);
            },
            child: Text(AppLocale.tr('i_authorized'),
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _pollForSession(BuildContext context, LastFmProvider lastfm) async {
    if (!context.mounted) return;
    final success = await lastfm.completeAuth();
    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.tr('auth_failed_try_again')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _YtMusicSettingsPage extends StatefulWidget {
  const _YtMusicSettingsPage();

  @override
  State<_YtMusicSettingsPage> createState() => _YtMusicSettingsPageState();
}

class _YtMusicSettingsPageState extends State<_YtMusicSettingsPage> {
  final _cookieController = TextEditingController();

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _submitCookie(YTMusicProvider ytmusic) async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) return;
    final success = await ytmusic.connectWithCookie(cookie);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('connected_as')),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ytmusic.error ?? AppLocale.tr('auth_failed_try_again')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('youtube_music')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Consumer<YTMusicProvider>(
        builder: (context, ytmusic, _) {
          if (ytmusic.isConnected) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsTile(
                  icon: Icons.link_rounded,
                  iconColor: Colors.red,
                  title: AppLocale.tr('youtube_music'),
                  subtitle: AppLocale.tr('connected_as'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ytmusic.disconnect();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppLocale.tr('disconnect'),
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final playlists = await ytmusic.importPlaylists();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${playlists.length} ${AppLocale.tr('playlists')} ${AppLocale.tr('import_songs')}'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.playlist_play_rounded),
                    label: Text(AppLocale.tr('playlists')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final songs = await ytmusic.importSongs();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${songs.length} ${AppLocale.tr('songs')} ${AppLocale.tr('import_songs')}'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.music_note_rounded),
                    label: Text(AppLocale.tr('import_songs')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppLocale.tr('connect_ytmusic_description'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocale.tr('ytmusic_cookie_instructions'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cookieController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppLocale.tr('paste_ytmusic_cookie'),
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitCookie(ytmusic),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitCookie(ytmusic),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(AppLocale.tr('connect_youtube_music')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (ytmusic.error != null) ...[
                const SizedBox(height: 16),
                Text(ytmusic.error!, style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SpotifySettingsPage extends StatefulWidget {
  const _SpotifySettingsPage();

  @override
  State<_SpotifySettingsPage> createState() => _SpotifySettingsPageState();
}

class _SpotifySettingsPageState extends State<_SpotifySettingsPage> {
  final _cookieController = TextEditingController();

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _submitCookie(SpotifyProvider spotify) async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) return;
    final success = await spotify.connectWithCookie(cookie);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('connected_as')),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(spotify.error ?? AppLocale.tr('auth_failed_try_again')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('spotify')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Consumer<SpotifyProvider>(
        builder: (context, spotify, _) {
          if (spotify.isConnected) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsTile(
                  icon: Icons.person_rounded,
                  iconColor: Colors.green,
                  title: AppLocale.tr('spotify_connected_as'),
                  subtitle: spotify.username ?? '',
                  trailing: TextButton(
                    onPressed: () async {
                      await spotify.disconnect();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppLocale.tr('disconnect'),
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: spotify.isImportingPlaylists
                        ? null
                        : () async {
                            final playlists = await spotify.importPlaylists();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${playlists.length} ${AppLocale.tr('playlists')} ${AppLocale.tr('import_songs')}'),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );
                            }
                          },
                    icon: spotify.isImportingPlaylists
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.playlist_play_rounded),
                    label: Text(AppLocale.tr('import_playlists')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: spotify.isImportingLikedSongs
                        ? null
                        : () async {
                            final songs = await spotify.importLikedSongs();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${songs.length} ${AppLocale.tr('songs')} ${AppLocale.tr('import_songs')}'),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );
                            }
                          },
                    icon: spotify.isImportingLikedSongs
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.favorite_rounded),
                    label: Text(AppLocale.tr('import_liked_songs')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppLocale.tr('connect_spotify_description'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocale.tr('spotify_cookie_instructions'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cookieController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppLocale.tr('paste_sp_dc_cookie'),
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitCookie(spotify),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitCookie(spotify),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(AppLocale.tr('spotify')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (spotify.error != null) ...[
                const SizedBox(height: 16),
                Text(spotify.error!, style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EqualizerPage extends StatefulWidget {
  const _EqualizerPage();

  @override
  State<_EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<_EqualizerPage> {
  bool _enabled = false;
  final List<double> _gains = [0, 0, 0, 0, 0];
  double _preamp = 0;
  double _bassBoost = 0;
  String _activePreset = 'flat';

  static const _bandFreqs = ['60', '230', '910', '3.6k', '14k'];
  static const _bandLabels = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];

  static const _presets = {
    'flat': 'Flat',
    'classical': 'Classical',
    'dance': 'Dance',
    'acoustic': 'Acoustic',
    'bass_boost': 'Bass Boost',
    'treble_boost': 'Treble Boost',
    'loudness': 'Loudness',
    'rock': 'Rock',
    'pop': 'Pop',
    'jazz': 'Jazz',
    'voice': 'Voice',
    'custom': 'Custom',
  };

  static const _presetValues = {
    'flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'classical': [0.0, 0.0, 0.0, 0.0, 0.0],
    'dance': [6.0, 4.0, 2.0, 0.0, 0.0],
    'acoustic': [4.0, 2.0, 0.0, 2.0, 4.0],
    'bass_boost': [8.0, 6.0, 0.0, -2.0, -2.0],
    'treble_boost': [-2.0, -2.0, 0.0, 4.0, 6.0],
    'loudness': [-4.0, -2.0, 0.0, 2.0, 4.0],
    'rock': [6.0, 4.0, -2.0, -4.0, 2.0],
    'pop': [-2.0, 4.0, 6.0, 4.0, -2.0],
    'jazz': [4.0, 2.0, 0.0, 2.0, 4.0],
    'voice': [-4.0, -2.0, 6.0, -2.0, -4.0],
  };

  void _applyPreset(String id) {
    setState(() {
      _activePreset = id;
      final values = _presetValues[id] ?? [0.0, 0.0, 0.0, 0.0, 0.0];
      for (int i = 0; i < 5; i++) {
        _gains[i] = values[i];
      }
      _bassBoost = id == 'bass_boost' ? 8.0 : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('equalizer')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master toggle
          Row(
            children: [
              Text(AppLocale.tr('equalizer'),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(AppLocale.tr('adjust_sound_frequencies'),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // EQ curve preview
          if (_enabled) ...[
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CustomPaint(
                size: const Size(double.infinity, 100),
                painter: _EqCurvePainter(
                  gains: _gains,
                  bassBoost: _bassBoost,
                  primaryColor: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Band sliders
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Column(
                  children: [
                    Text('${_gains[i].isNegative ? '' : '+'}${_gains[i].toInt()}',
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 140,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: (_gains[i] + 12) / 24,
                          onChanged: _enabled ? (v) {
                            setState(() {
                              _gains[i] = (v * 24) - 12;
                              _activePreset = 'custom';
                            });
                          } : null,
                          activeColor: AppTheme.primaryColor,
                          inactiveColor: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_bandFreqs[i],
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Presets
          Text(AppLocale.tr('presets').toUpperCase(),
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _presets.entries.map((e) {
                final selected = _activePreset == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    label: Text(e.value, style: TextStyle(fontSize: 12)),
                    onSelected: _enabled ? (v) => _applyPreset(e.key) : null,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    checkmarkColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Bass Boost
          if (_enabled) ...[
            _buildSlider('Bass Boost', _bassBoost, 0, 15, (v) => setState(() {
              _bassBoost = v;
              if (_activePreset != 'bass_boost') _activePreset = 'custom';
            })),
            const SizedBox(height: 16),
          ],

          // Pre-amp
          if (_enabled) ...[
            _buildSlider('Pre-amp', _preamp, -12, 12, (v) => setState(() => _preamp = v)),
          ],
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: AppTheme.primaryColor,
                inactiveColor: AppTheme.textTertiary,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text('${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
      ],
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  final List<double> gains;
  final double bassBoost;
  final Color primaryColor;

  _EqCurvePainter({
    required this.gains,
    required this.bassBoost,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final midY = size.height / 2;
    final h = size.height * 0.45;
    final w = size.width;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i <= 64; i++) {
      final xNorm = i / 64;
      final bandPos = xNorm * 4;
      final lo = bandPos.floor().clamp(0, 3);
      final hi = (lo + 1).clamp(0, 4);
      final t = bandPos - lo;
      final tSmooth = (1 - cos(t * 3.14159)) / 2;

      double gainDb = gains[lo] * (1 - tSmooth) + gains[hi] * tSmooth;
      if (lo == 0) gainDb += bassBoost * 0.5;

      final x = xNorm * w;
      final y = midY - (gainDb / 12) * h;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(w, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // center line
    final centerPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), centerPaint);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter old) =>
      gains != old.gains || bassBoost != old.bassBoost;
}

class _StreamingSettingsPage extends StatefulWidget {
  const _StreamingSettingsPage();

  @override
  State<_StreamingSettingsPage> createState() => _StreamingSettingsPageState();
}

class _StreamingSettingsPageState extends State<_StreamingSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('streaming')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SettingsTile(
                icon: Icons.cloud_rounded,
                iconColor: Colors.lightBlue,
                title: AppLocale.tr('online_mode'),
                subtitle: AppLocale.tr('streaming'),
                trailing: Switch(
                  value: settings.streamingEnabled,
                  onChanged: (v) {
                    settings.setStreamingEnabled(v);
                    context.read<PlayerProvider>().setStreamingEnabled(v);
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                onTap: () {
                  final v = !settings.streamingEnabled;
                  settings.setStreamingEnabled(v);
                  context.read<PlayerProvider>().setStreamingEnabled(v);
                },
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.signal_cellular_alt_rounded,
                iconColor: Colors.green,
                title: AppLocale.tr('stream_on_cellular'),
                subtitle: AppLocale.tr('streaming'),
                trailing: Switch(
                  value: settings.streamOnCellular,
                  onChanged: (v) => settings.setStreamOnCellular(v),
                  activeColor: AppTheme.primaryColor,
                ),
                onTap: () {
                  final v = !settings.streamOnCellular;
                  settings.setStreamOnCellular(v);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SyncSettingsPage extends StatefulWidget {
  const _SyncSettingsPage();

  @override
  State<_SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<_SyncSettingsPage> {
  bool _syncEnabled = false;
  TimeOfDay _syncTime = const TimeOfDay(hour: 3, minute: 0);
  bool _wifiOnly = true;
  Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  String _dayLabel(int day) {
    final df = DateFormat('E', AppLocale.currentLocale);
    return df.format(DateTime(2024, 1, day + 1));
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await context.read<SyncProvider>().service.loadPreferences();
    if (!mounted) return;
    setState(() {
      _syncEnabled = prefs['enabled'] as bool;
      _syncTime = TimeOfDay(hour: prefs['hour'] as int, minute: prefs['minute'] as int);
      _wifiOnly = prefs['wifiOnly'] as bool;
      _selectedDays = (prefs['days'] as List).cast<int>().toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('auto_sync')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsTile(
            icon: Icons.sync_rounded,
            iconColor: Colors.teal,
            title: AppLocale.tr('auto_sync'),
            subtitle: AppLocale.tr('sync_schedule'),
            trailing: Switch(
              value: _syncEnabled,
              onChanged: (v) {
                setState(() => _syncEnabled = v);
                final provider = context.read<SyncProvider>();
                if (v) {
                  provider.scheduleSync(
                    hour: _syncTime.hour,
                    minute: _syncTime.minute,
                    wifiOnly: _wifiOnly,
                    days: _selectedDays.toList(),
                  );
                } else {
                  provider.cancelSync();
                }
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () {
              final v = !_syncEnabled;
              setState(() => _syncEnabled = v);
              final provider = context.read<SyncProvider>();
              if (v) {
                provider.scheduleSync(
                  hour: _syncTime.hour,
                  minute: _syncTime.minute,
                  wifiOnly: _wifiOnly,
                  days: _selectedDays.toList(),
                );
              } else {
                provider.cancelSync();
              }
            },
          ),
          if (_syncEnabled) ...[
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.access_time_rounded,
              iconColor: Colors.orange,
              title: AppLocale.tr('sync_time'),
              subtitle: _syncTime.format(context),
              trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _syncTime,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: AppTheme.primaryColor,
                        surface: AppTheme.surface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => _syncTime = picked);
                  context.read<SyncProvider>().scheduleSync(
                    hour: picked.hour,
                    minute: picked.minute,
                    wifiOnly: _wifiOnly,
                    days: _selectedDays.toList(),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.wifi_rounded,
              iconColor: Colors.blue,
              title: AppLocale.tr('wifi_only'),
              subtitle: AppLocale.tr('sync_schedule'),
              trailing: Switch(
                value: _wifiOnly,
                onChanged: (v) {
                  setState(() => _wifiOnly = v);
                  context.read<SyncProvider>().scheduleSync(
                    hour: _syncTime.hour,
                    minute: _syncTime.minute,
                    wifiOnly: v,
                    days: _selectedDays.toList(),
                  );
                },
                activeColor: AppTheme.primaryColor,
              ),
              onTap: () {
                final v = !_wifiOnly;
                setState(() => _wifiOnly = v);
                context.read<SyncProvider>().scheduleSync(
                  hour: _syncTime.hour,
                  minute: _syncTime.minute,
                  wifiOnly: v,
                  days: _selectedDays.toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            _SectionTitle(AppLocale.tr('sync_schedule')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                  final selected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(_dayLabel(day)),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                      context.read<SyncProvider>().scheduleSync(
                        hour: _syncTime.hour,
                        minute: _syncTime.minute,
                        wifiOnly: _wifiOnly,
                        days: _selectedDays.toList(),
                      );
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    checkmarkColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const List<Color> _accentColors = [
  Color(0xFF1DB954),
  Color(0xFF1ED760),
  Color(0xFFFA233B),
  Color(0xFFFF2D55),
  Color(0xFF007AFF),
  Color(0xFF5856D6),
  Color(0xFFAF52DE),
  Color(0xFFFF9500),
  Color(0xFFFFCC02),
  Color(0xFF34C759),
  Color(0xFF00C7BE),
  Color(0xFFFFFFFF),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFF2196F3),
  Color(0xFF00BCD4),
  Color(0xFF4CAF50),
  Color(0xFFFF5722),
  Color(0xFF795548),
  Color(0xFF607D8B),
];

class _CustomColorTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? currentColor;
  final Color defaultColor;
  final ValueChanged<Color?> onChanged;

  const _CustomColorTile({
    required this.label,
    required this.icon,
    required this.currentColor,
    required this.defaultColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = currentColor ?? defaultColor;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      subtitle: Text(
        currentColor != null
            ? '#${currentColor!.value.toRadixString(16).substring(2).toUpperCase()}'
            : AppLocale.tr('default_color'),
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentColor != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => onChanged(null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: AppTheme.textTertiary,
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showColorPicker(context),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.textTertiary, width: 2),
              ),
            ),
          ),
        ],
      ),
      onTap: () => _showColorPicker(context),
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(label,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _accentColors.map((c) {
                  final isSelected = currentColor?.value == c.value;
                  return GestureDetector(
                    onTap: () {
                      onChanged(c);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.black, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (currentColor != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  onChanged(null);
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: Text(AppLocale.tr('default_color')),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final dynamic subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget? subtitleWidget;
    if (subtitle is String) {
      subtitleWidget = Text(subtitle as String,
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12));
    } else if (subtitle is Widget) {
      subtitleWidget = subtitle as Widget;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 15)),
      subtitle: subtitleWidget,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
