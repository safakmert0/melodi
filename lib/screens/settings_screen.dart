import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'English';
  double _crossfadeSeconds = 0;
  double _defaultPlaybackSpeed = 1.0;
  double _defaultVolumeBoost = 1.0;
  bool _autoShuffle = false;
  bool _gaplessPlayback = true;

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, PlayerProvider>(
      builder: (context, library, player, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: const Text(
                'Settings',
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
                  const _SectionTitle('Language'),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.teal,
                    title: 'App Language',
                    subtitle: _selectedLanguage,
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showLanguagePicker(context),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Library section
                  const _SectionTitle('Music Library'),
                  _SettingsTile(
                    icon: Icons.refresh_rounded,
                    iconColor: AppTheme.primaryColor,
                    title: 'Rescan Library',
                    subtitle: 'Scan device for new or removed music',
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
                    title: 'Import from Files',
                    subtitle: 'Browse and import audio files',
                    onTap: () =>
                        context.read<LibraryProvider>().importFromFiles(),
                  ),
                  _SettingsTile(
                    icon: Icons.folder_special_rounded,
                    iconColor: Colors.purple,
                    title: 'Import from Folder',
                    subtitle: 'Scan a specific folder for music',
                    onTap: () =>
                        context.read<LibraryProvider>().importFromDirectory(),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Storage section
                  const _SectionTitle('Storage'),
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
                              const Text(
                                'Local Songs',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${library.songCount} songs in library',
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
                    title: 'Clear Library',
                    subtitle: 'Remove all cached music data',
                    onTap: () => _confirmClearLibrary(context),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Audio section
                  const _SectionTitle('Audio'),
                  _SettingsTile(
                    icon: Icons.equalizer_rounded,
                    iconColor: Colors.teal,
                    title: 'Equalizer',
                    subtitle: 'Adjust sound frequencies',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.speed_rounded,
                    iconColor: Colors.cyan,
                    title: 'Default Playback Speed',
                    subtitle: '${_defaultPlaybackSpeed.toStringAsFixed(2)}x',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showSpeedPicker(context),
                  ),
                  _SettingsTile(
                    icon: Icons.volume_up_rounded,
                    iconColor: Colors.blue,
                    title: 'Volume Boost',
                    subtitle: '${(_defaultVolumeBoost * 100).round()}%',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showVolumeBoostSlider(context),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // Playback section
                  const _SectionTitle('Playback'),
                  _SettingsTile(
                    icon: Icons.shuffle_rounded,
                    iconColor: Colors.amber,
                    title: 'Auto Shuffle',
                    subtitle: 'Automatically shuffle when playing',
                    trailing: Switch(
                      value: _autoShuffle,
                      onChanged: (v) {
                        setState(() => _autoShuffle = v);
                        player.setAutoShuffle(v);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {
                      setState(() => _autoShuffle = !_autoShuffle);
                      player.setAutoShuffle(_autoShuffle);
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.waves_rounded,
                    iconColor: Colors.pink,
                    title: 'Gapless Playback',
                    subtitle: 'Seamless transition between songs',
                    trailing: Switch(
                      value: _gaplessPlayback,
                      onChanged: (v) {
                        setState(() => _gaplessPlayback = v);
                        player.setGaplessPlayback(v);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {
                      setState(() => _gaplessPlayback = !_gaplessPlayback);
                      player.setGaplessPlayback(_gaplessPlayback);
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: Colors.indigo,
                    title: 'Crossfade',
                    subtitle: '${_crossfadeSeconds.toInt()}s crossfade',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () => _showCrossfadeSlider(context, player),
                  ),
                  const Divider(color: AppTheme.darkDivider, height: 1),
                  // About section
                  const _SectionTitle('About'),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.textSecondary,
                    title: 'Melodi',
                    subtitle: 'Version ${AppConstants.appVersion}',
                  ),
                  _SettingsTile(
                    icon: Icons.code_rounded,
                    iconColor: AppTheme.textSecondary,
                    title: 'Flutter Music Player',
                    subtitle: 'Built with Flutter & Love',
                  ),
                  _SettingsTile(
                    icon: Icons.favorite_rounded,
                    iconColor: AppTheme.favoriteColor,
                    title: 'Credits',
                    subtitle: 'Open source components & licenses',
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
            const Text('App Language',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...[
              ('English', 'en'),
              ('Turkish', 'tr'),
              ('German', 'de'),
            ].map((entry) {
              return ListTile(
                title: Text(entry.$1,
                    style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: _selectedLanguage == entry.$1
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  setState(() => _selectedLanguage = entry.$1);
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
            const Text('Default Playback Speed',
                style: TextStyle(
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
                  context.read<PlayerProvider>().setPlaybackSpeed(speed);
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
                  const Text('Volume Boost',
                      style: TextStyle(
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
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Apply'),
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
                  const Text('Crossfade',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${localCrossfade.toInt()} seconds',
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
                      Text('Off',
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
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Apply'),
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

  void _confirmClearLibrary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Clear Library',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will remove all cached music data. Your actual music files will not be deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<LibraryProvider>().clearLibrary();
              Navigator.pop(context);
            },
            child: const Text('Clear',
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
