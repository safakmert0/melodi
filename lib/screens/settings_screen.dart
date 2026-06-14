import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/library_provider.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
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
                    subtitle: '1.0x',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.volume_up_rounded,
                    iconColor: Colors.blue,
                    title: 'Volume Boost',
                    subtitle: 'Boost playback volume',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () {},
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
                      value: false,
                      onChanged: (_) {},
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.waves_rounded,
                    iconColor: Colors.pink,
                    title: 'Gapless Playback',
                    subtitle: 'Seamless transition between songs',
                    trailing: Switch(
                      value: true,
                      onChanged: (_) {},
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: Colors.indigo,
                    title: 'Crossfade',
                    subtitle: 'Crossfade between tracks (0s)',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                    onTap: () {},
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
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
