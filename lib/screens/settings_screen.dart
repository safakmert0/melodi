import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
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
                  // Theme section
                  _SectionTitle(AppLocale.tr('appearance')),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      final themeLabel = themeProvider.isDark
                          ? AppLocale.tr('dark')
                          : themeProvider.isLight
                              ? AppLocale.tr('light')
                              : AppLocale.tr('system');
                      return Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.dark_mode_rounded,
                            iconColor: Colors.amber,
                            title: AppLocale.tr('theme'),
                            subtitle: themeLabel,
                            trailing: Icon(Icons.chevron_right,
                                color: AppTheme.textTertiary),
                            onTap: () => _showThemePicker(context, themeProvider),
                          ),
                          const SizedBox(height: 8),
                          _SettingsTile(
                            icon: Icons.palette_rounded,
                            iconColor: Colors.pink,
                            title: AppLocale.tr('accent_color'),
                            subtitle: AppLocale.tr('tap_to_change'),
                            trailing: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: themeProvider.accentColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.textTertiary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap: () => _showAccentColorPicker(context, themeProvider),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.divider, height: 1),
                  // Language section
                  _SectionTitle(AppLocale.tr('language')),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.teal,
                    title: AppLocale.tr('app_language'),
                    subtitle: _selectedLanguage,
                    trailing: Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showLanguagePicker(context),
                  ),
                  Divider(color: AppTheme.divider, height: 1),
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
                            icon: Icon(Icons.close, color: AppTheme.textTertiary, size: 18),
                            onPressed: () async {
                              await context.read<LibraryProvider>().clearWatchedFolder();
                              setState(() => _watchedFolderPath = '');
                            },
                          )
                        : null,
                    onTap: () => _pickWatchedFolder(context),
                  ),
                  Divider(color: AppTheme.divider, height: 1),
                  // Storage section
                  _SectionTitle(AppLocale.tr('storage')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.storage_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocale.tr('local_songs'),
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${library.songCount} ${AppLocale.tr('songs_in_library')}',
                                style: TextStyle(
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
                  Divider(color: AppTheme.divider, height: 1),
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
                    trailing: Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showCrossfadeSlider(context, player),
                  ),
                  Divider(color: AppTheme.divider, height: 1),
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
                  Divider(color: AppTheme.divider, height: 1),
                  // About section
                  _SectionTitle(AppLocale.tr('about')),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.textSecondary,
                    title: 'Melodi',
                    subtitle: '${AppLocale.tr('version')} ${AppConstants.appVersion}',
                  ),
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
              trailing: themeProvider.isDark ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.light_mode_rounded, color: themeProvider.isLight ? AppTheme.primaryColor : AppTheme.textTertiary),
              title: Text(AppLocale.tr('light'), style: TextStyle(color: AppTheme.textPrimary)),
              trailing: themeProvider.isLight ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_brightness_rounded, color: themeProvider.isSystem ? AppTheme.primaryColor : AppTheme.textTertiary),
              title: Text(AppLocale.tr('system'), style: TextStyle(color: AppTheme.textPrimary)),
              trailing: themeProvider.isSystem ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
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

  static const List<Color> _accentColors = [
    Color(0xFF1DB954), // Spotify green
    Color(0xFF1ED760), // Bright green
    Color(0xFFFA233B), // Apple Music red
    Color(0xFFFF2D55), // iOS red
    Color(0xFF007AFF), // iOS blue
    Color(0xFF5856D6), // iOS purple
    Color(0xFFAF52DE), // iOS magenta
    Color(0xFFFF9500), // iOS orange
    Color(0xFFFFCC02), // iOS yellow
    Color(0xFF34C759), // iOS green
    Color(0xFF00C7BE), // iOS teal
    Color(0xFFFFFFFF), // White
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Deep purple
    Color(0xFF2196F3), // Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF4CAF50), // Material green
    Color(0xFFFF5722), // Deep orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue grey
  ];

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
                      style: const TextStyle(
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
          style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
