import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import 'support_screen.dart';
import 'downloads_screen.dart';
import 'storage_screen.dart';
import 'extension_store_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedLanguage;
  String _appVersion = AppConstants.appVersion;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _localeName(AppLocale.currentLocale);
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  String _localeName(String code) {
    switch (code) {
      case 'tr':
        return 'TÜRKÇE';
      case 'de':
        return 'Deutsch';
      default:
        return 'English';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: theme.appBarTheme.backgroundColor ??
                theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            title: Text(
              AppLocale.tr('settings'),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
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
                  trailing:
                      Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                  onTap: () => _showLanguagePicker(context),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: Colors.amber,
                  title: AppLocale.tr('theme'),
                  subtitle: Consumer<ThemeProvider>(
                    builder: (context, tp, _) => Text(
                      tp.isDark
                          ? AppLocale.tr('dark')
                          : tp.isLight
                              ? AppLocale.tr('light')
                              : AppLocale.tr('system'),
                      style: TextStyle(
                          color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const _AppearanceSettingsPage()),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: MelodiTheme.outlineVariant, height: 1),
                _SectionTitle(AppLocale.tr('music_library')),
                Consumer<LibraryProvider>(
                  builder: (context, library, _) => _SettingsTile(
                    icon: Icons.refresh_rounded,
                    iconColor: MelodiTheme.primaryGreen,
                    title: AppLocale.tr('rescan_library'),
                    subtitle: AppLocale.tr('scan_device_for_music'),
                    trailing: library.isScanning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MelodiTheme.primaryGreen),
                          )
                        : null,
                    onTap: () => library.scanMusic(),
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<LibraryProvider>(
                  builder: (context, library, _) => _SettingsTile(
                    icon: Icons.folder_open_rounded,
                    iconColor: Colors.orange,
                    title: AppLocale.tr('import_from_files'),
                    subtitle: AppLocale.tr('browse_and_import'),
                    onTap: () => library.importFromFiles(),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.download_rounded,
                  iconColor: Colors.green,
                  title: AppLocale.tr('downloads'),
                  subtitle: AppLocale.tr('downloads'),
                  trailing:
                      Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<LibraryProvider>(
                  builder: (context, library, _) => _SettingsTile(
                    icon: Icons.storage_rounded,
                    iconColor: Colors.cyan,
                    title: AppLocale.tr('storage'),
                    subtitle: Text(
                      '${_formatBytes(library.totalSongSizeBytes)} · ${AppLocale.tr('library_size')}',
                      style: TextStyle(
                          color: MelodiTheme.onSurfaceVariant, fontSize: 12),
                    ),
                    trailing:
                        Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StorageScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: MelodiTheme.outlineVariant, height: 1),
                _SectionTitle('Eklentiler'),
                _SettingsTile(
                  icon: Icons.extension_rounded,
                  iconColor: MelodiTheme.primaryGreen,
                  title: 'Eklenti Mağazası',
                  subtitle: 'yt-dlp ve diğer sağlayıcıları kur',
                  trailing:
                      Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ExtensionStoreScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: MelodiTheme.outlineVariant, height: 1),
                _SectionTitle(AppLocale.tr('about')),
                _SettingsTile(
                  icon: Icons.volunteer_activism_rounded,
                  iconColor: MelodiTheme.primaryGreen,
                  title: 'Destek Ol',
                  subtitle: 'Bağış yaparak geliştirmeyi destekle',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: MelodiTheme.onSurfaceVariant,
                  title: 'Melodi',
                  subtitle: '${AppLocale.tr('version')} $_appVersion',
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: MelodiTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(AppLocale.tr('app_language'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...[
              ('TÜRKÇE', 'tr'),
              ('English', 'en'),
              ('Deutsch', 'de'),
            ].map((entry) {
              return ListTile(
                title: Text(entry.$1,
                    style: TextStyle(color: MelodiTheme.onSurface)),
                trailing: _selectedLanguage == entry.$1
                    ? Icon(Icons.check, color: MelodiTheme.primaryGreen)
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

  void _showAcknowledgments(BuildContext context) {
    const projects = <({String name, String role, String url})>[
      (
        name: 'yt-dlp',
        role: 'Medya çözümleme ve indirme ilhamı',
        url: 'https://github.com/yt-dlp/yt-dlp'
      ),
      (
        name: 'Media3',
        role: 'Android medya altyapısı',
        url: 'https://github.com/androidx/media'
      ),
      (
        name: 'youtube_explode_dart',
        role: 'YouTube akış çözümleme',
        url: 'https://github.com/Hexer10/youtube_explode_dart'
      ),
      (
        name: 'just_audio',
        role: 'Çapraz platform oynatıcı',
        url: 'https://github.com/ryanheise/just_audio'
      ),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: MelodiTheme.primaryGreen, size: 24),
            const SizedBox(width: 12),
            Text(AppLocale.tr('acknowledgments'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: min(MediaQuery.sizeOf(ctx).height * 0.58, 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Melodi, açık kaynak topluluğunun emeğiyle gelişiyor.',
                  style: TextStyle(
                      color: MelodiTheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: MelodiTheme.outlineVariant, height: 1),
                  itemBuilder: (_, i) {
                    final p = projects[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name,
                          style: TextStyle(color: MelodiTheme.onSurface)),
                      subtitle: Text(p.role,
                          style: TextStyle(
                              color: MelodiTheme.onSurfaceVariant,
                              fontSize: 12)),
                      trailing: Icon(Icons.open_in_new_rounded,
                          color: MelodiTheme.primaryGreen, size: 18),
                      onTap: () => _openUrl(p.url),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Kapat',
                  style: TextStyle(color: MelodiTheme.primaryGreen))),
        ],
      ),
    );
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
              backgroundColor: MelodiTheme.errorRed),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      );
}

class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(AppLocale.tr('appearance'))),
      body: Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SectionTitle(AppLocale.tr('theme_mode')),
              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.amber,
                title: AppLocale.tr('theme'),
                subtitle: tp.isDark
                    ? AppLocale.tr('dark')
                    : tp.isLight
                        ? AppLocale.tr('light')
                        : AppLocale.tr('system'),
                trailing: Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                onTap: () => _showThemePicker(context, tp),
              ),
              const SizedBox(height: 16),
              _SectionTitle(AppLocale.tr('accent_color')),
              const SizedBox(height: 8),
              ..._accentColors.map((c) {
                final sel = tp.accentColor.value == c.value;
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: sel ? Colors.white : Colors.transparent,
                          width: 2),
                    ),
                    child: sel
                        ? const Icon(Icons.check, color: Colors.black, size: 16)
                        : null,
                  ),
                  title: Text(_accentColorName(c),
                      style: Theme.of(context).textTheme.titleMedium),
                  trailing: sel
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20)
                      : null,
                  onTap: () => tp.setAccentColor(c),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _accentColorName(Color c) {
    const m = {
      0xFF1ED760: 'color_green',
      0xFFFA233B: 'color_red',
      0xFF007AFF: 'color_blue',
      0xFFAF52DE: 'color_purple',
      0xFFFF9500: 'color_orange',
    };
    final k = m[c.value];
    if (k != null) return AppLocale.tr(k);
    return '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _showThemePicker(BuildContext context, ThemeProvider tp) {
    showModalBottomSheet(
      context: context,
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
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(AppLocale.tr('theme'),
                  style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 24),
              _themeOption(ctx, tp, AppLocale.tr('system'), null),
              _themeOption(ctx, tp, AppLocale.tr('light'), false),
              _themeOption(ctx, tp, AppLocale.tr('dark'), true),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(
      BuildContext ctx, ThemeProvider tp, String label, bool? isDark) {
    final sel = isDark == null
        ? tp.themeMode == ThemeMode.system
        : isDark
            ? tp.isDark
            : tp.isLight;
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
          color: sel ? cs.primary : cs.onSurfaceVariant),
      title: Text(label, style: TextStyle(color: cs.onSurface)),
      onTap: () {
        if (isDark == null) {
          tp.setThemeMode(ThemeMode.system);
        } else if (isDark) {
          tp.setThemeMode(ThemeMode.dark);
        } else {
          tp.setThemeMode(ThemeMode.light);
        }
        Navigator.pop(ctx);
      },
    );
  }
}

const List<Color> _accentColors = [
  Color(0xFF1ED760), // Yeşil (varsayılan)
  Color(0xFF007AFF), // Mavi
  Color(0xFFAF52DE), // Mor
  Color(0xFFFF9500), // Turuncu
  Color(0xFFFA233B), // Kırmızı
];

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final dynamic subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile(
      {required this.icon,
      required this.iconColor,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget? subtitleWidget;
    if (subtitle is String) {
      subtitleWidget = Text(subtitle as String,
          style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant, fontSize: 12));
    } else if (subtitle is Widget) {
      subtitleWidget = subtitle as Widget;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15)),
        subtitle: subtitleWidget,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
