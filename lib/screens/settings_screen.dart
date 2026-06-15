import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedLanguage;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _localeName(AppLocale.currentLocale);
    _loadWatchedFolder();
    _loadPlaybackSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  Future<void> _loadPlaybackSettings() async {
    final db = DatabaseService.instance;
    final speed = await db.getSetting('default_playback_speed');
    final volume = await db.getSetting('default_volume_boost');
    final crossfade = await db.getSetting('crossfade_seconds');
    final shuffle = await db.getSetting('auto_shuffle');
    final gapless = await db.getSetting('gapless_playback');
    if (mounted) {
      setState(() {
        _defaultPlaybackSpeed = double.tryParse(speed ?? '') ?? 1.0;
        _defaultVolumeBoost = double.tryParse(volume ?? '') ?? 1.0;
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
  double _defaultPlaybackSpeed = 1.0;
  double _defaultVolumeBoost = 1.0;
  bool _autoShuffle = false;
  bool _gaplessPlayback = true;
  String _watchedFolderPath = '';

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
                  // Language section
                  _SectionTitle(AppLocale.tr('language')),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.teal,
                    title: AppLocale.tr('app_language'),
                    subtitle: _selectedLanguage,
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showLanguagePicker(context),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Library section
                  _SectionTitle(AppLocale.tr('music_library')),
                  _SettingsTile(
                    icon: Icons.refresh_rounded,
                    iconColor: AppTheme.primaryColor,
                    title: AppLocale.tr('rescan_library'),
                    subtitle: AppLocale.tr('scan_device_for_music'),
                    trailing: library.isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : null,
                    onTap: () => context.read<LibraryProvider>().scanMusic(),
                  ),
                  _SettingsTile(
                    icon: Icons.folder_open_rounded,
                    iconColor: Colors.orange,
                    title: AppLocale.tr('import_from_files'),
                    subtitle: AppLocale.tr('browse_and_import'),
                    onTap: () =>
                        context.read<LibraryProvider>().importFromFiles(),
                  ),
                  _SettingsTile(
                    icon: Icons.folder_special_rounded,
                    iconColor: Colors.purple,
                    title: AppLocale.tr('import_from_folder_title'),
                    subtitle: AppLocale.tr('scan_folder_for_music'),
                    onTap: () =>
                        context.read<LibraryProvider>().importFromDirectory(),
                  ),
                  _SettingsTile(
                    icon: Icons.folder_rounded,
                    iconColor: Colors.deepPurple,
                    title: AppLocale.tr('watched_folder'),
                    subtitle: _watchedFolderPath.isNotEmpty
                        ? '${AppLocale.tr('watching')}: $_watchedFolderPath'
                        : AppLocale.tr('auto_scan_folder'),
                    trailing: _watchedFolderPath.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textTertiary, size: 18),
                            onPressed: () async {
                              await context.read<LibraryProvider>().clearWatchedFolder();
                              setState(() => _watchedFolderPath = '');
                            },
                          )
                        : null,
                    onTap: () => _pickWatchedFolder(context),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Storage section
                  _SectionTitle(AppLocale.tr('storage')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.storage_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocale.tr('local_songs'),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${library.songCount} ${AppLocale.tr('songs_in_library')}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
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
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Audio section
                  _SectionTitle(AppLocale.tr('audio')),
                  _SettingsTile(
                    icon: Icons.equalizer_rounded,
                    iconColor: Colors.teal,
                    title: AppLocale.tr('equalizer'),
                    subtitle: AppLocale.tr('adjust_sound_frequencies'),
                    onTap: () => _showEqualizerComingSoon(context),
                  ),
                  _SettingsTile(
                    icon: Icons.speed_rounded,
                    iconColor: Colors.cyan,
                    title: AppLocale.tr('default_playback_speed'),
                    subtitle: '${_defaultPlaybackSpeed.toStringAsFixed(2)}x',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showSpeedPicker(context),
                  ),
                  _SettingsTile(
                    icon: Icons.volume_up_rounded,
                    iconColor: Colors.blue,
                    title: AppLocale.tr('volume_boost'),
                    subtitle: '${(_defaultVolumeBoost * 100).round()}%',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showVolumeBoostSlider(context),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Playback section
                  _SectionTitle(AppLocale.tr('playback')),
                  _SettingsTile(
                    icon: Icons.shuffle_rounded,
                    iconColor: Colors.amber,
                    title: AppLocale.tr('auto_shuffle'),
                    subtitle: AppLocale.tr('automatically_shuffle'),
                    trailing: Switch(
                      value: _autoShuffle,
                      onChanged: (v) {
                        setState(() => _autoShuffle = v);
                        player.setAutoShuffle(v);
                        DatabaseService.instance.setSetting('auto_shuffle', v.toString());
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {
                      final v = !_autoShuffle;
                      setState(() => _autoShuffle = v);
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
                      value: _gaplessPlayback,
                      onChanged: (v) {
                        setState(() => _gaplessPlayback = v);
                        player.setGaplessPlayback(v);
                        DatabaseService.instance.setSetting('gapless_playback', v.toString());
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {
                      final v = !_gaplessPlayback;
                      setState(() => _gaplessPlayback = v);
                      player.setGaplessPlayback(v);
                      DatabaseService.instance.setSetting('gapless_playback', v.toString());
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: Colors.indigo,
                    title: AppLocale.tr('crossfade'),
                    subtitle: '${_crossfadeSeconds.toInt()}${AppLocale.tr('seconds_crossfade')}',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showCrossfadeSlider(context, player),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Developer section
                  _SectionTitle(AppLocale.tr('developer')),
                  _SettingsTile(
                    icon: Icons.code_rounded,
                    iconColor: Colors.grey,
                    title: 'GitHub',
                    subtitle: 'safakmert0',
                    onTap: () => _openUrl('https://github.com/safakmert0'),
                  ),
                  _SettingsTile(
                    icon: Icons.send_rounded,
                    iconColor: Colors.lightBlue,
                    title: 'Telegram',
                    subtitle: '@safakmert',
                    onTap: () => _openUrl('https://t.me/safakmert'),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // About section
                  _SectionTitle(AppLocale.tr('about')),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.textSecondary,
                    title: 'Melodi',
                    subtitle: '${AppLocale.tr('version')} $_appVersion',
                  ),
                  _SettingsTile(
                    icon: Icons.favorite_rounded,
                    iconColor: AppTheme.favoriteColor,
                    title: AppLocale.tr('credits'),
                    subtitle: AppLocale.tr('open_source_licenses'),
                    onTap: () {},
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

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
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
                color: AppTheme.darkDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('app_language'),
                style: const TextStyle(
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
                    style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: _selectedLanguage == entry.$1
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
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

  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
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
                color: AppTheme.darkDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('default_playback_speed'),
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
              ...speeds.map((speed) {
              return ListTile(
                title: Text('${speed}x',
                    style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: _defaultPlaybackSpeed == speed
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  setState(() => _defaultPlaybackSpeed = speed);
                  final playerProv = context.read<PlayerProvider>();
                  playerProv.setPlaybackSpeed(speed);
                  DatabaseService.instance.setSetting('default_playback_speed', speed.toString());
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

  void _showVolumeBoostSlider(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        double localVolume = _defaultVolumeBoost;
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
                      color: AppTheme.darkDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(AppLocale.tr('volume_boost'),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${(localVolume * 100).round()}%',
                      style: const TextStyle(
                          color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  Slider(
                    value: localVolume,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: AppTheme.darkDivider,
                    onChanged: (v) {
                      setSheetState(() => localVolume = v);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('50%',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                      Text('200%',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _defaultVolumeBoost = localVolume);
                        context.read<PlayerProvider>().setVolume(localVolume);
                        DatabaseService.instance.setSetting('default_volume_boost', localVolume.toString());
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

  void _showCrossfadeSlider(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
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
                      color: AppTheme.darkDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(AppLocale.tr('crossfade'),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${localCrossfade.toInt()} ${AppLocale.tr('seconds')}',
                      style: const TextStyle(
                          color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  Slider(
                    value: localCrossfade,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: AppTheme.darkDivider,
                    onChanged: (v) {
                      setSheetState(() => localCrossfade = v);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocale.tr('off'),
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
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

  void _showEqualizerComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(AppLocale.tr('equalizer'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          AppLocale.tr('equalizer_coming_soon'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
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
      selectedDirectory = await FilePicker.platform.getDirectoryPath();
    }

    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      await lib.setWatchedFolder(selectedDirectory);
      setState(() => _watchedFolderPath = selectedDirectory);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watching: $selectedDirectory'),
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
        backgroundColor: AppTheme.darkSurface,
        title: Text(AppLocale.tr('clear_library_title'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          AppLocale.tr('clear_library_confirm'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<LibraryProvider>().clearLibrary();
              Navigator.pop(context);
            },
            child: Text(AppLocale.tr('delete'),
                style: const TextStyle(color: AppTheme.errorColor)),
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
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
