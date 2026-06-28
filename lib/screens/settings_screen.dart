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
import '../providers/like_mirror_provider.dart';
import '../providers/scrobble_provider.dart';
import '../services/scrobble_service.dart';
import '../providers/settings_provider.dart';
import '../providers/metadata_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/download_provider.dart';
import '../services/database_service.dart';
import '../services/library_health_service.dart';
import '../services/playback_service.dart';
import '../services/file_organizer.dart';
import '../services/stream_cache.dart';
import '../services/audiobook_service.dart';
import 'audio_quality_screen.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/crossfade_slider.dart';
import '../widgets/spotify_webview_login.dart';
import 'diagnostics_screen.dart';
import 'failed_downloads_screen.dart';
import 'downloads_screen.dart';
import 'blocked_tracks_screen.dart';
import 'shared_urls_screen.dart';
import 'library_health_screen.dart';
import 'storage_screen.dart';
import '../widgets/ytmusic_webview_login.dart';
import 'backend_settings_screen.dart';

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
    final btAutoEq = await db.getSetting('bluetooth_auto_eq');
    if (mounted) {
      setState(() {
        _crossfadeSeconds = double.tryParse(crossfade ?? '') ?? 0;
        _autoShuffle = shuffle == 'true';
        _gaplessPlayback = gapless != 'false';
        _bluetoothAutoEq = btAutoEq == 'true';
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
  bool _bluetoothAutoEq = false;
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
              backgroundColor: const Color(0xFF131313),
              surfaceTintColor: Colors.transparent,
              title: Text(
                AppLocale.tr('settings'),
                style: const TextStyle(
                  color: Color(0xFFe5e2e1),
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
                  _CollapsibleSection(
                    title: AppLocale.tr('general'),
                    children: [
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        iconColor: Colors.teal,
                        title: AppLocale.tr('app_language'),
                        subtitle: _selectedLanguage,
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('playback'),
                    children: [
                      _PlaybackTile(
                        icon: Icons.dark_mode_rounded,
                        iconColor: Colors.indigo,
                        title: AppLocale.tr('sleep_timer'),
                        subtitleBuilder: () {
                          final svc = PlaybackService.instance;
                          if (svc.isSleepTimerActive) {
                            final rem = svc.getRemainingTime();
                            final m = rem.inMinutes;
                            final s = rem.inSeconds.remainder(60);
                            return '${AppLocale.tr('timer_active')} (${m}:${s.toString().padLeft(2, '0')})';
                          }
                          return null;
                        },
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: MelodiTheme.containerLow,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (_) => const SleepTimerSheet(),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _PlaybackTile(
                        icon: Icons.swap_horiz_rounded,
                        iconColor: Colors.indigo,
                        title: AppLocale.tr('crossfade'),
                        subtitleBuilder: () {
                          final crossfade = _crossfadeSeconds.toInt();
                          if (crossfade > 0) return '$crossfade ${AppLocale.tr('seconds')}';
                          return AppLocale.tr('off');
                        },
                        onTap: () {
                          final player = context.read<PlayerProvider>();
                          _showCrossfadeSlider(context, player);
                        },
                      ),
                      const SizedBox(height: 8),
                      _PlaybackTile(
                        icon: Icons.tune_rounded,
                        iconColor: Colors.purple,
                        title: AppLocale.tr('equalizer'),
                        subtitleBuilder: () => AppLocale.tr('adjust_sound_frequencies'),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const EqualizerSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('music_library'),
                    children: [
                      _SettingsTile(
                        icon: Icons.refresh_rounded,
                        iconColor: MelodiTheme.primaryGreen,
                        title: AppLocale.tr('rescan_library'),
                        subtitle: AppLocale.tr('scan_device_for_music'),
                        trailing: library.isScanning
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.primaryGreen),
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
                                icon: Icon(Icons.close, color: MelodiTheme.textMuted, size: 18),
                                onPressed: () async {
                                  await library.clearWatchedFolder();
                                  setState(() => _watchedFolderPath = '');
                                },
                              )
                            : null,
                        onTap: () => _pickWatchedFolder(context),
                      ),
                      const SizedBox(height: 8),
                      _LibraryHealthSettingsTile(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('metadata_backfill'),
                    children: [
                      Consumer<MetadataProvider>(
                        builder: (context, md, _) => Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.image_rounded,
                              iconColor: Colors.indigo,
                              title: AppLocale.tr('backfill_art'),
                              subtitle: md.isBackfilling
                                  ? '${AppLocale.tr('backfill_progress')}: ${md.backfillProgress}/${md.backfillTotal}'
                                  : md.lastBackfilledAt != null
                                      ? '${AppLocale.tr('last_backfilled')}: ${_formatDateTime(md.lastBackfilledAt!)}'
                                      : null,
                              trailing: md.isBackfilling
                                  ? SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.primaryGreen),
                                    )
                                  : null,
                              onTap: md.isBackfilling ? null : () => md.startBackfillAlbumArt(),
                            ),
                            const SizedBox(height: 8),
                            _SettingsTile(
                              icon: Icons.article_rounded,
                              iconColor: Colors.pink,
                              title: AppLocale.tr('backfill_lyrics'),
                              subtitle: md.isBackfilling
                                  ? '${AppLocale.tr('backfill_progress')}: ${md.backfillProgress}/${md.backfillTotal}'
                                  : md.lastBackfilledAt != null
                                      ? '${AppLocale.tr('last_backfilled')}: ${_formatDateTime(md.lastBackfilledAt!)}'
                                      : null,
                              trailing: md.isBackfilling
                                  ? SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.primaryGreen),
                                    )
                                  : null,
                              onTap: md.isBackfilling ? null : () => md.startBackfillLyrics(),
                            ),
                            const SizedBox(height: 8),
                            _SettingsTile(
                              icon: Icons.high_quality_rounded,
                              iconColor: Colors.amber,
                              title: AppLocale.tr('high_res_art'),
                              subtitle: AppLocale.tr('backfill_art'),
                              onTap: md.isBackfilling ? null : () => md.startBackfillAlbumArt(),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: md.isBackfilling ? null : () => md.startBackfillAll(),
                                  icon: md.isBackfilling
                                      ? SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.primaryGreen),
                                        )
                                      : Icon(Icons.refresh_rounded, size: 18),
                                  label: Text(AppLocale.tr('backfill_all')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: MelodiTheme.primaryGreen,
                                    side: BorderSide(color: MelodiTheme.primaryGreen),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('storage'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.storage_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppLocale.tr('local_songs'),
                                      style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15)),
                                  Text(
                                    '${library.songCount} ${AppLocale.tr('songs_in_library')} · ${_formatBytes(library.totalSongSizeBytes)}',
                                    style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
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
                        iconColor: MelodiTheme.errorRed,
                        title: AppLocale.tr('clear_library'),
                        subtitle: AppLocale.tr('remove_cached_data'),
                        onTap: () => _confirmClearLibrary(context),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.block_rounded,
                        iconColor: Colors.red,
                        title: AppLocale.tr('blocklist'),
                        subtitle: AppLocale.tr('blocked_count'),
                        trailing: FutureBuilder<int>(
                          future: DatabaseService.instance.rawQuery('SELECT COUNT(*) as count FROM blocked_tracks').then((r) => (r.first['count'] as int?) ?? 0),
                          builder: (_, snap) {
                            final count = snap.data ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: MelodiTheme.errorRed.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count > 0 ? '$count' : '0',
                                style: TextStyle(color: MelodiTheme.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BlockedTracksScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.link_rounded,
                        iconColor: Colors.blue,
                        title: 'Shared Links',
                        subtitle: AppLocale.tr('no_shared_links'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SharedUrlsScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('accounts'),
                    children: [
                  // Last.fm
                  Consumer<LastFmProvider>(
                    builder: (context, lastfm, _) {
                      if (lastfm.isConnected) {
                        return _SettingsTile(
                          icon: Icons.radio_rounded,
                          iconColor: Colors.red,
                          title: AppLocale.tr('lastfm'),
                          subtitle: '${AppLocale.tr('connected_as')} ${lastfm.username}',
                          trailing: TextButton(
                            onPressed: () => lastfm.disconnect(),
                            child: Text(AppLocale.tr('disconnect'),
                                style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const _LastFmSettingsPage()),
                          ),
                        );
                      }
                      return _SettingsTile(
                        icon: Icons.radio_rounded,
                        iconColor: Colors.red,
                        title: AppLocale.tr('lastfm'),
                        subtitle: AppLocale.tr('lastfm_connect'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                                style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
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
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                                style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
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
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _YtMusicSettingsPage()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.dns_rounded,
                    iconColor: MelodiTheme.primaryGreen,
                    title: 'YT-DLP Backend',
                    subtitle: 'Gerçek yt-dlp motoru için backend ayarları',
                    trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BackendSettingsScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.schedule_rounded,
                    iconColor: Colors.teal,
                    title: AppLocale.tr('scheduled_sync'),
                    subtitle: FutureBuilder<Map<String, dynamic>>(
                      future: context.read<SyncProvider>().service.loadPreferences(),
                      builder: (_, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        final data = snap.data!;
                        final enabled = data['enabled'] as bool;
                        if (!enabled) return Text(AppLocale.tr('off'));
                        final hour = data['hour'] as int;
                        final minute = data['minute'] as int;
                        final time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                        return Text('${AppLocale.tr('sync_enabled')} · $time');
                      },
                    ),
                    trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _SyncSettingsPage()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer2<SpotifyProvider, YTMusicProvider>(
                    builder: (context, spotify, ytmusic, _) {
                      if (!spotify.isConnected || !ytmusic.isConnected) {
                        return const SizedBox.shrink();
                      }
                      return _SettingsTile(
                        icon: Icons.sync_alt_rounded,
                        iconColor: Colors.blue,
                        title: AppLocale.tr('like_mirroring'),
                        subtitle: AppLocale.tr('mirror_likes_description'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _LikeMirrorSettingsPage()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Consumer2<SpotifyProvider, YTMusicProvider>(
                    builder: (context, spotify, ytmusic, _) {
                      if (!spotify.isConnected || !ytmusic.isConnected) {
                        return const SizedBox.shrink();
                      }
                      return _SettingsTile(
                        icon: Icons.sync_alt_rounded,
                        iconColor: Colors.teal,
                        title: AppLocale.tr('default_sync'),
                        subtitle: AppLocale.tr('sync_settings'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _DefaultSyncSettingsPage()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Consumer2<SpotifyProvider, YTMusicProvider>(
                    builder: (context, spotify, ytmusic, _) {
                      if (!spotify.isConnected || !ytmusic.isConnected) {
                        return const SizedBox.shrink();
                      }
                      return _SettingsTile(
                        icon: Icons.history_rounded,
                        iconColor: Colors.orange,
                        title: AppLocale.tr('yt_history_scrobbling'),
                        subtitle: AppLocale.tr('scrobbling'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _ScrobbleSettingsPage()),
                        ),
                      );
                    },
                  ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('audio'),
                    children: [
                      _SettingsTile(
                        icon: Icons.tune_rounded,
                        iconColor: Colors.purple,
                        title: AppLocale.tr('equalizer'),
                        subtitle: AppLocale.tr('adjust_sound_frequencies'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _EqualizerPage()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.equalizer,
                        iconColor: const Color(0xFF53e076),
                        title: 'Audio Effects',
                        subtitle: 'Spatial audio, reverb, bass boost',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _AudioEffectsPage()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.tune,
                        iconColor: Colors.teal,
                        title: 'EQ Presets',
                        subtitle: 'Choose from preset equalizer profiles',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => _showEqPresetsDialog(context),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.queue_music,
                        iconColor: Colors.cyan,
                        title: 'Gapless Playback',
                        subtitle: 'Seamless transitions between tracks',
                        trailing: Switch(
                          value: _gaplessPlayback,
                          onChanged: (v) {
                            setState(() => _gaplessPlayback = v);
                            context.read<PlayerProvider>().setGaplessPlayback(v);
                            DatabaseService.instance.setSetting('gapless_playback', v.toString());
                          },
                          activeColor: const Color(0xFF53e076),
                        ),
                        onTap: () {
                          final v = !_gaplessPlayback;
                          setState(() => _gaplessPlayback = v);
                          context.read<PlayerProvider>().setGaplessPlayback(v);
                          DatabaseService.instance.setSetting('gapless_playback', v.toString());
                        },
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.swap_horiz,
                        iconColor: Colors.indigo,
                        title: 'Crossfade',
                        subtitle: _crossfadeSeconds.toInt() > 0
                            ? '${_crossfadeSeconds.toInt()} seconds'
                            : AppLocale.tr('off'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => _showCrossfadeSlider(context, context.read<PlayerProvider>()),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.bluetooth,
                        iconColor: Colors.blue,
                        title: 'Bluetooth Auto-EQ',
                        subtitle: 'Automatically adjust EQ for Bluetooth devices',
                        trailing: Switch(
                          value: _bluetoothAutoEq,
                          onChanged: (v) {
                            setState(() => _bluetoothAutoEq = v);
                            DatabaseService.instance.setSetting('bluetooth_auto_eq', v.toString());
                          },
                          activeColor: const Color(0xFF53e076),
                        ),
                        onTap: () {
                          setState(() => _bluetoothAutoEq = !_bluetoothAutoEq);
                          DatabaseService.instance.setSetting('bluetooth_auto_eq', _bluetoothAutoEq.toString());
                        },
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.mic,
                        iconColor: Colors.orange,
                        title: 'Siri Shortcuts',
                        subtitle: 'Configure voice control shortcuts',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _VoiceControlPage()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.cast,
                        iconColor: Colors.deepPurple,
                        title: 'AirPlay',
                        subtitle: 'Stream to available AirPlay devices',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => _showAirPlayDevicesDialog(context),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.headphones,
                        iconColor: Colors.pink,
                        title: 'Podcast',
                        subtitle: 'Manage podcast subscriptions',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _PodcastSubscriptionsPage()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.menu_book,
                        iconColor: Colors.brown,
                        title: 'Audiobook',
                        subtitle: 'Browse audiobook library',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _AudiobookLibraryPage()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.widgets,
                        iconColor: Colors.amber,
                        title: 'Widget',
                        subtitle: 'Configure home screen widgets',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => _showWidgetConfigDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('streaming'),
                    children: [
                      Consumer<SettingsProvider>(
                        builder: (context, settings, _) => _SettingsTile(
                          icon: Icons.cloud_rounded,
                          iconColor: Colors.lightBlue,
                          title: AppLocale.tr('streaming'),
                          subtitle: settings.streamingEnabled
                              ? AppLocale.tr('online_mode')
                              : AppLocale.tr('offline_mode'),
                          trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _SyncSettingsPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('lossless'),
                    children: [
                      _LosslessDownloadsSection(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('downloads'),
                    children: [
                      Consumer<DownloadProvider>(
                        builder: (context, dp, _) => _SettingsTile(
                          icon: Icons.download_rounded,
                          iconColor: Colors.green,
                          title: AppLocale.tr('downloads'),
                          subtitle: dp.isDownloading
                              ? '${dp.activeCount} active · ${dp.completedCount} completed'
                              : '${dp.completedCount} ${AppLocale.tr('completed')}',
                          trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<DownloadProvider>(
                        builder: (context, dp, _) {
                          if (dp.failedCount == 0) return const SizedBox.shrink();
                          return _SettingsTile(
                            icon: Icons.error_outline_rounded,
                            iconColor: MelodiTheme.errorRed,
                            title: AppLocale.tr('failed'),
                            subtitle: '${dp.failedCount} ${AppLocale.tr('failed')}',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: MelodiTheme.errorRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${dp.failedCount}',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FailedDownloadsScreen()),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.folder_rounded,
                        iconColor: Colors.orange,
                        title: AppLocale.tr('download_location'),
                        subtitle: 'Documents/downloads',
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () async {
                          final db = DatabaseService.instance;
                          final dir = await db.getSetting('download_path');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(dir ?? 'Documents/downloads'),
                                backgroundColor: MelodiTheme.primaryGreen,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.tune_rounded,
                        iconColor: Colors.pink,
                        title: AppLocale.tr('audio_quality'),
                        subtitle: AppLocale.tr('streaming_quality'),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AudioQualityScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.folder_rounded,
                        iconColor: Colors.amber,
                        title: AppLocale.tr('file_organization'),
                        subtitle: FutureBuilder<bool>(
                          future: FileOrganizer().isOrganized(),
                          builder: (_, snap) {
                            final organized = snap.data ?? false;
                            return Text(
                              organized ? AppLocale.tr('organized_by_artist') : AppLocale.tr('flat_structure'),
                              style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 12),
                            );
                          },
                        ),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => _showFileOrganizationDialog(context),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.storage_rounded,
                        iconColor: Colors.cyan,
                        title: AppLocale.tr('storage'),
                        subtitle: Text(
                          '${_formatBytes(context.read<LibraryProvider>().totalSongSizeBytes)} · ${AppLocale.tr('library_size')}',
                          style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StorageScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.cached_rounded,
                        iconColor: Colors.cyan,
                        title: AppLocale.tr('stream_cache'),
                        subtitle: FutureBuilder<int>(
                          future: StreamCache().getCacheSize(),
                          builder: (_, snap) {
                            final size = snap.data ?? 0;
                            return Text(
                              '${_formatBytes(size)}',
                              style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                            );
                          },
                        ),
                        trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
                        onTap: () => _showStreamCacheDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('developer'),
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  _CollapsibleSection(
                    title: AppLocale.tr('about'),
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: MelodiTheme.onSurfaceVariant,
                        title: 'Melodi',
                        subtitle: '${AppLocale.tr('version')} ${AppConstants.appVersion}',
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: MelodiTheme.primaryGreen,
                        title: AppLocale.tr('acknowledgments'),
                        subtitle: 'yt-dlp, Media3, ytmusicapi ve diğerleri',
                        onTap: () => _showAcknowledgments(context),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.favorite_rounded,
                        iconColor: MelodiTheme.primaryGreen,
                        title: AppLocale.tr('credits'),
                        subtitle: AppLocale.tr('open_source_licenses'),
                        onTap: () => _showCredits(context),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.bug_report_rounded,
                        iconColor: Colors.orange,
                        title: AppLocale.tr('diagnostics'),
                        subtitle: AppLocale.tr('crash_reports'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                        ),
                      ),
                    ],
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

  void _showStreamCacheDialog(BuildContext context) {
    final streamCache = StreamCache();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(AppLocale.tr('stream_cache'),
            style: TextStyle(color: MelodiTheme.onSurface)),
        content: FutureBuilder<int>(
          future: streamCache.getCacheSize(),
          builder: (_, snap) {
            final size = snap.data ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(AppLocale.tr('cache_size'),
                          style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14)),
                    ),
                    Expanded(
                      child: Text(_formatBytes(size),
                          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await streamCache.clearCache();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocale.tr('cache_cleared')),
                            backgroundColor: MelodiTheme.primaryGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(AppLocale.tr('clear_cache')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MelodiTheme.errorRed,
                      side: BorderSide(color: MelodiTheme.errorRed),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('theme'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.dark_mode_rounded, color: themeProvider.isDark ? MelodiTheme.primaryGreen : MelodiTheme.textMuted),
              title: Text(AppLocale.tr('dark'), style: TextStyle(color: MelodiTheme.onSurface)),
              trailing: themeProvider.isDark ? Icon(Icons.check, color: MelodiTheme.primaryGreen) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.light_mode_rounded, color: themeProvider.isLight ? MelodiTheme.primaryGreen : MelodiTheme.textMuted),
              title: Text(AppLocale.tr('light'), style: TextStyle(color: MelodiTheme.onSurface)),
              trailing: themeProvider.isLight ? Icon(Icons.check, color: MelodiTheme.primaryGreen) : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_brightness_rounded, color: themeProvider.isSystem ? MelodiTheme.primaryGreen : MelodiTheme.textMuted),
              title: Text(AppLocale.tr('system'), style: TextStyle(color: MelodiTheme.onSurface)),
              trailing: themeProvider.isSystem ? Icon(Icons.check, color: MelodiTheme.primaryGreen) : null,
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
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('accent_color'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
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
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
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
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('app_language'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
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

  void _showCrossfadeSlider(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
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
                      color: MelodiTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(AppLocale.tr('crossfade'),
                      style: TextStyle(
                          color: MelodiTheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${localCrossfade.toInt()} ${AppLocale.tr('seconds')}',
                      style: TextStyle(
                          color: MelodiTheme.primaryGreen, fontSize: 32, fontWeight: FontWeight.bold)),
                  Slider(
                    value: localCrossfade,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    activeColor: MelodiTheme.primaryGreen,
                    inactiveColor: MelodiTheme.outlineVariant,
                    onChanged: (v) {
                      setSheetState(() => localCrossfade = v);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocale.tr('off'),
                          style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
                      Text('12s',
                          style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
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
                        backgroundColor: MelodiTheme.primaryGreen,
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

  void _showFileOrganizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(AppLocale.tr('file_organization'),
            style: TextStyle(color: MelodiTheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocale.tr('file_organization'),
                style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FileOrganizer().organizeDownloads();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocale.tr('organize_now')),
                        backgroundColor: MelodiTheme.primaryGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.folder_rounded, size: 18),
                label: Text(AppLocale.tr('organize_now')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MelodiTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FileOrganizer().flattenStructure();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocale.tr('flat_structure')),
                        backgroundColor: MelodiTheme.primaryGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.unfold_less_rounded, size: 18),
                label: Text(AppLocale.tr('flat_structure')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MelodiTheme.onSurface,
                  side: BorderSide(color: MelodiTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FileOrganizer().organizeDownloads(dryRun: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocale.tr('preview')),
                      backgroundColor: MelodiTheme.primaryGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.preview_rounded, size: 18),
                label: Text(AppLocale.tr('preview')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MelodiTheme.onSurface,
                  side: BorderSide(color: MelodiTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcknowledgments(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: MelodiTheme.primaryGreen, size: 24),
            const SizedBox(width: 12),
            Text(
              AppLocale.tr('acknowledgments'),
              style: TextStyle(color: MelodiTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Melodi, aşağıdaki açık kaynak projeler sayesinde hayata geçti:',
                  style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _ackItem(
                  'yt-dlp',
                  'https://github.com/yt-dlp/yt-dlp',
                  'YouTube metadata ve ses çekme mimarisinin ilham kaynağı',
                ),
                _ackItem(
                  'Media3 / ExoPlayer',
                  'https://github.com/androidx/media',
                  'Ses oynatma altyapısı (just_audio üzerinden)',
                ),
                _ackItem(
                  'ytmusicapi',
                  'https://github.com/sigma67/ytmusicapi',
                  'YouTube Music API tersine mühendislik referansı',
                ),
                _ackItem(
                  'youtube_explode_dart',
                  'https://github.com/hexrcs/youtube_explode_dart',
                  'YouTube video/metadata çekme kütüphanesi',
                ),
                _ackItem(
                  'LRCLIB',
                  'https://lrclib.net',
                  'Senkronize şarkı sözü sağlayıcısı',
                ),
                _ackItem(
                  'just_audio',
                  'https://github.com/ryanheise/just_audio',
                  'Platformlar arası ses oynatma',
                ),
                _ackItem(
                  'flutter_secure_storage',
                  'https://github.com/mogol/flutter_secure_storage',
                  'Güvenli kimlik bilgisi saklama',
                ),
                _ackItem(
                  'sqflite',
                  'https://github.com/tekartik/sqflite',
                  'Yerel veritabanı',
                ),
                _ackItem(
                  'palette_generator',
                  'https://github.com/flutter/packages',
                  'Dinamik renk paleti çıkarma',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Kapat', style: TextStyle(color: MelodiTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _ackItem(String name, String url, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _openUrl(url),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: MelodiTheme.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.code_rounded, color: MelodiTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: MelodiTheme.textMuted, size: 16),
          ],
        ),
      ),
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
          color: MelodiTheme.primaryGreen,
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
            backgroundColor: MelodiTheme.primaryGreen,
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
            backgroundColor: MelodiTheme.errorRed,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  void _confirmClearLibrary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(AppLocale.tr('clear_library_title'),
            style: TextStyle(color: MelodiTheme.onSurface)),
        content: Text(
          AppLocale.tr('clear_library_confirm'),
          style: TextStyle(color: MelodiTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              context.read<LibraryProvider>().clearLibrary();
              Navigator.pop(context);
            },
            child: Text(AppLocale.tr('delete'),
                style: TextStyle(color: MelodiTheme.errorRed)),
          ),
        ],
      ),
    );
  }

}

class _PlaybackTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? Function() subtitleBuilder;
  final VoidCallback onTap;

  const _PlaybackTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitleBuilder,
    required this.onTap,
  });

  @override
  State<_PlaybackTile> createState() => _PlaybackTileState();
}

class _PlaybackTileState extends State<_PlaybackTile> {
  @override
  void initState() {
    super.initState();
    if (widget.title == AppLocale.tr('sleep_timer')) {
      PlaybackService.instance.sleepTimerStream.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitleBuilder();
    return _SettingsTile(
      icon: widget.icon,
      iconColor: widget.iconColor,
      title: widget.title,
      subtitle: subtitle,
      trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
      onTap: widget.onTap,
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool startExpanded;

  const _CollapsibleSection({
    required this.title,
    required this.children,
    this.startExpanded = true,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF53e076),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF53e076),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Column(children: widget.children),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
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
          color: Color(0xFF53e076),
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
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('appearance')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
                trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
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
                    style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: MelodiTheme.primaryGreen, size: 20)
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
                defaultColor: MelodiTheme.background == MelodiTheme.background ? MelodiTheme.background : MelodiTheme.background,
                onChanged: (c) => themeProvider.setCustomBackground(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('surface'),
                icon: Icons.square_rounded,
                currentColor: themeProvider.customSurface,
                defaultColor: MelodiTheme.background == MelodiTheme.background ? MelodiTheme.containerLow : MelodiTheme.containerLow,
                onChanged: (c) => themeProvider.setCustomSurface(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('card'),
                icon: Icons.crop_square_rounded,
                currentColor: themeProvider.customCard,
                defaultColor: MelodiTheme.background == MelodiTheme.background ? MelodiTheme.containerLow : MelodiTheme.containerLow,
                onChanged: (c) => themeProvider.setCustomCard(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('text_primary'),
                icon: Icons.text_fields_rounded,
                currentColor: themeProvider.customTextPrimary,
                defaultColor: MelodiTheme.background == MelodiTheme.background ? const Color(0xFF1A1A1A) : Colors.white,
                onChanged: (c) => themeProvider.setCustomTextPrimary(c),
              ),
              _CustomColorTile(
                label: AppLocale.tr('text_secondary'),
                icon: Icons.text_fields_rounded,
                currentColor: themeProvider.customTextSecondary,
                defaultColor: MelodiTheme.background == MelodiTheme.background ? const Color(0xFF666666) : const Color(0xFFB3B3B3),
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
      backgroundColor: MelodiTheme.containerLow,
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
                  color: MelodiTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(AppLocale.tr('theme'),
                  style: TextStyle(color: MelodiTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
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
        color: selected ? MelodiTheme.primaryGreen : MelodiTheme.textMuted,
      ),
      title: Text(label, style: TextStyle(color: MelodiTheme.onSurface)),
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
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('playback')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
              activeColor: MelodiTheme.primaryGreen,
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
              activeColor: MelodiTheme.primaryGreen,
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
            trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
            onTap: () => _showCrossfadeSlider(context),
          ),
        ],
      ),
    );
  }

  void _showCrossfadeSlider(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
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
                    color: MelodiTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppLocale.tr('crossfade'),
                    style: TextStyle(color: MelodiTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${_crossfade.toInt()} ${AppLocale.tr('seconds_crossfade')}',
                  style: TextStyle(color: MelodiTheme.primaryGreen, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _crossfade,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  activeColor: MelodiTheme.primaryGreen,
                  inactiveColor: MelodiTheme.textMuted,
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
                      backgroundColor: MelodiTheme.primaryGreen,
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
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  Future<void> _showConnectDialog(BuildContext context, LastFmProvider lastfm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(AppLocale.tr('connect_lastfm'),
            style: TextStyle(color: MelodiTheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: AppLocale.tr('lastfm_api_key'),
                labelStyle: TextStyle(color: MelodiTheme.onSurfaceVariant),
                filled: true,
                fillColor: MelodiTheme.containerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: MelodiTheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiSecretController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocale.tr('lastfm_api_secret'),
                labelStyle: TextStyle(color: MelodiTheme.onSurfaceVariant),
                filled: true,
                fillColor: MelodiTheme.containerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: MelodiTheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocale.tr('connect_lastfm'),
                style: TextStyle(color: MelodiTheme.primaryGreen)),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final apiKey = _apiKeyController.text.trim();
      final apiSecret = _apiSecretController.text.trim();
      if (apiKey.isEmpty || apiSecret.isEmpty) return;
      final success = await lastfm.connect(apiKey, apiSecret);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocale.tr('connected_as')} ${lastfm.username}'),
              backgroundColor: MelodiTheme.primaryGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lastfm.error ?? AppLocale.tr('auth_failed_try_again')),
              backgroundColor: MelodiTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('lastfm')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
                  subtitle: lastfm.sessionKey != null
                      ? 'Session: ${lastfm.sessionKey!.substring(0, 8)}...'
                      : null,
                  trailing: TextButton(
                    onPressed: () async {
                      await lastfm.disconnect();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppLocale.tr('disconnect'),
                        style: TextStyle(color: MelodiTheme.errorRed)),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.radio_rounded,
                  iconColor: Colors.red,
                  title: AppLocale.tr('lastfm_scrobbling'),
                  trailing: Switch(
                    value: lastfm.scrobbleEnabled,
                    onChanged: (v) => lastfm.setScrobbleEnabled(v),
                    activeColor: MelodiTheme.primaryGreen,
                  ),
                  onTap: () => lastfm.setScrobbleEnabled(!lastfm.scrobbleEnabled),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppLocale.tr('lastfm_description'),
                style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (lastfm.isConnecting)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showConnectDialog(context, lastfm),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(AppLocale.tr('connect_lastfm')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MelodiTheme.primaryGreen,
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
                Text(lastfm.error!, style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _YtMusicSettingsPage extends StatefulWidget {
  const _YtMusicSettingsPage();

  @override
  State<_YtMusicSettingsPage> createState() => _YtMusicSettingsPageState();
}

class _YtMusicSettingsPageState extends State<_YtMusicSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('youtube_music')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
                        style: TextStyle(color: MelodiTheme.errorRed)),
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
                            backgroundColor: MelodiTheme.primaryGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.playlist_play_rounded),
                    label: Text(AppLocale.tr('playlists')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MelodiTheme.primaryGreen,
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
                            backgroundColor: MelodiTheme.primaryGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.music_note_rounded),
                    label: Text(AppLocale.tr('import_songs')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
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
                style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => YTMusicWebViewLogin(
                          onCookieObtained: (cookie) async {
                            Navigator.of(context).pop();
                            final success = await ytmusic.connectWithCookie(cookie);
                            if (context.mounted) {
                              if (success) {
                                context.read<SyncProvider>().triggerSync();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocale.tr('connected_as')),
                                    backgroundColor: MelodiTheme.primaryGreen,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ytmusic.error ?? AppLocale.tr('auth_failed_try_again')),
                                    backgroundColor: MelodiTheme.errorRed,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.language_rounded),
                  label: Text(AppLocale.tr('login_with_browser')),
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
                Text(ytmusic.error!, style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('spotify')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
                        style: TextStyle(color: MelodiTheme.errorRed)),
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
                                  backgroundColor: MelodiTheme.primaryGreen,
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
                      backgroundColor: MelodiTheme.primaryGreen,
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
                                  backgroundColor: MelodiTheme.primaryGreen,
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
                      backgroundColor: Colors.green.withOpacity(0.8),
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
                style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpotifyWebViewLogin(
                          onCookieObtained: (spDc) async {
                            Navigator.of(context).pop();
                            final success = await spotify.connectWithCookie(spDc);
                            if (context.mounted) {
                              if (success) {
                                context.read<SyncProvider>().triggerSync();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocale.tr('connected_as')),
                                    backgroundColor: MelodiTheme.primaryGreen,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(spotify.error ?? AppLocale.tr('auth_failed_try_again')),
                                    backgroundColor: MelodiTheme.errorRed,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.language_rounded),
                  label: Text(AppLocale.tr('login_with_browser')),
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
                Text(spotify.error!, style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    final enabled = await db.getSetting('eq_enabled');
    final gains = await db.getSetting('eq_gains');
    final preset = await db.getSetting('eq_preset');
    if (mounted) {
      setState(() {
        _enabled = enabled == 'true';
        _activePreset = preset ?? 'flat';
        if (gains != null) {
          final parts = gains.split(',');
          for (int i = 0; i < 5 && i < parts.length; i++) {
            _gains[i] = double.tryParse(parts[i]) ?? 0;
          }
        }
      });
    }
  }

  Future<void> _saveAndApply() async {
    final db = DatabaseService.instance;
    await db.setSetting('eq_enabled', _enabled.toString());
    await db.setSetting('eq_gains', _gains.map((g) => g.toStringAsFixed(1)).join(','));
    await db.setSetting('eq_preset', _activePreset);
  }

  void _applyPreset(String id) {
    setState(() {
      _activePreset = id;
      final values = _presetValues[id] ?? [0.0, 0.0, 0.0, 0.0, 0.0];
      for (int i = 0; i < 5; i++) {
        _gains[i] = values[i];
      }
      _bassBoost = id == 'bass_boost' ? 8.0 : 0.0;
    });
    _saveAndApply();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('equalizer')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master toggle
          Row(
            children: [
              Text(AppLocale.tr('equalizer'),
                  style: TextStyle(color: MelodiTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _enabled,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  _saveAndApply();
                },
                activeColor: MelodiTheme.primaryGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(AppLocale.tr('adjust_sound_frequencies'),
              style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
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
                  primaryColor: MelodiTheme.primaryGreen,
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
                        style: TextStyle(color: MelodiTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
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
                            _saveAndApply();
                          } : null,
                          activeColor: MelodiTheme.primaryGreen,
                          inactiveColor: MelodiTheme.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_bandFreqs[i],
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Presets
          Text(AppLocale.tr('presets').toUpperCase(),
              style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
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
                    selectedColor: MelodiTheme.primaryGreen.withOpacity(0.3),
                    checkmarkColor: MelodiTheme.primaryGreen,
                    backgroundColor: MelodiTheme.containerLow,
                    labelStyle: TextStyle(
                      color: selected ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant,
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
            _buildSlider('Bass Boost', _bassBoost, 0, 15, (v) {
              setState(() {
                _bassBoost = v;
                if (_activePreset != 'bass_boost') _activePreset = 'custom';
              });
              _saveAndApply();
            }),
            const SizedBox(height: 16),
          ],

          // Pre-amp
          if (_enabled) ...[
            _buildSlider('Pre-amp', _preamp, -12, 12, (v) {
              setState(() => _preamp = v);
              _saveAndApply();
            }),
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
            style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: MelodiTheme.primaryGreen,
                inactiveColor: MelodiTheme.textMuted,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text('${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
                  style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 12),
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
      ..color = primaryColor.withOpacity(0.1)
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
      ..color = primaryColor.withOpacity(0.15)
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
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('streaming')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
                  activeColor: MelodiTheme.primaryGreen,
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
                  activeColor: MelodiTheme.primaryGreen,
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
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('auto_sync')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
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
              activeColor: MelodiTheme.primaryGreen,
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
              trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _syncTime,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: MelodiTheme.primaryGreen,
                        surface: MelodiTheme.containerLow,
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
                activeColor: MelodiTheme.primaryGreen,
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
                    selectedColor: MelodiTheme.primaryGreen.withOpacity(0.3),
                    checkmarkColor: MelodiTheme.primaryGreen,
                    backgroundColor: MelodiTheme.containerLow,
                    labelStyle: TextStyle(
                      color: selected ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant,
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

class _DefaultSyncSettingsPage extends StatefulWidget {
  const _DefaultSyncSettingsPage();

  @override
  State<_DefaultSyncSettingsPage> createState() => _DefaultSyncSettingsPageState();
}

class _DefaultSyncSettingsPageState extends State<_DefaultSyncSettingsPage> {
  bool _autoSync = false;
  String _direction = 'bidirectional';

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final db = DatabaseService.instance;
    final autoSync = await db.getSetting('default_auto_sync');
    final direction = await db.getSetting('default_sync_direction');
    if (mounted) {
      setState(() {
        _autoSync = autoSync == 'true';
        _direction = direction ?? 'bidirectional';
      });
    }
  }

  Future<void> _save() async {
    final db = DatabaseService.instance;
    await db.setSetting('default_auto_sync', _autoSync.toString());
    await db.setSetting('default_sync_direction', _direction);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.tr('save')),
          backgroundColor: MelodiTheme.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('default_sync')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocale.tr('sync_settings'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.autorenew_rounded,
            iconColor: Colors.teal,
            title: AppLocale.tr('auto_sync'),
            subtitle: AppLocale.tr('sync_schedule'),
            trailing: Switch(
              value: _autoSync,
              onChanged: (v) => setState(() => _autoSync = v),
              activeColor: MelodiTheme.primaryGreen,
            ),
            onTap: () => setState(() => _autoSync = !_autoSync),
          ),
          const SizedBox(height: 16),
          _SectionTitle(AppLocale.tr('sync_direction')),
          const SizedBox(height: 8),
          _buildDirectionOption('bidirectional', AppLocale.tr('bidirectional')),
          _buildDirectionOption('spotify_to_yt', AppLocale.tr('spotify_to_yt')),
          _buildDirectionOption('yt_to_spotify', AppLocale.tr('yt_to_spotify')),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: Text(AppLocale.tr('save')),
              style: ElevatedButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionOption(String value, String label) {
    final selected = _direction == value;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? MelodiTheme.primaryGreen : MelodiTheme.textMuted,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? MelodiTheme.primaryGreen : MelodiTheme.onSurface,
          fontSize: 15,
        ),
      ),
      onTap: () => setState(() => _direction = value),
    );
  }
}

class _LikeMirrorSettingsPage extends StatelessWidget {
  const _LikeMirrorSettingsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LikeMirrorProvider>();
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('like_mirroring')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocale.tr('mirror_likes_description'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.sync_alt_rounded,
            iconColor: Colors.blue,
            title: AppLocale.tr('mirror_likes'),
            trailing: Switch(
              value: provider.enabled,
              onChanged: (v) => provider.setEnabled(v),
              activeColor: MelodiTheme.primaryGreen,
            ),
            onTap: () => provider.setEnabled(!provider.enabled),
          ),
          const SizedBox(height: 16),
          if (provider.enabled)
            _SettingsTile(
              icon: Icons.check_circle_rounded,
              iconColor: Colors.green,
              title: AppLocale.tr('mirroring_enabled'),
              subtitle: provider.isMirroring
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MelodiTheme.primaryGreen,
                      ),
                    )
                  : null,
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.isMirroring ? null : () => provider.mirrorNow(),
              icon: provider.isMirroring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(AppLocale.tr('mirror_now')),
              style: ElevatedButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (provider.lastMirroredAt != null) ...[
            _InfoRow(
              label: AppLocale.tr('last_mirrored'),
              value: _formatDateTime(provider.lastMirroredAt!),
            ),
            const SizedBox(height: 8),
          ],
          _InfoRow(
            label: AppLocale.tr('mirrored_count'),
            value: '${provider.mirroredCount}',
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 16),
            Text(provider.error!, style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ScrobbleSettingsPage extends StatelessWidget {
  const _ScrobbleSettingsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScrobbleProvider>();
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('yt_history_scrobbling')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocale.tr('yt_history_scrobbling'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.history_rounded,
            iconColor: Colors.orange,
            title: AppLocale.tr('scrobbling_enabled'),
            trailing: Switch(
              value: provider.enabled,
              onChanged: (v) {
                if (v) {
                  provider.enable();
                } else {
                  provider.disable();
                }
              },
              activeColor: MelodiTheme.primaryGreen,
            ),
            onTap: () {
              if (provider.enabled) {
                provider.disable();
              } else {
                provider.enable();
              }
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.isScrobbling ? null : () => provider.scrobbleNow(),
              icon: provider.isScrobbling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(AppLocale.tr('scrobble_now')),
              style: ElevatedButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (provider.lastScrobbledAt != null) ...[
            _InfoRow(
              label: AppLocale.tr('last_scrobbled'),
              value: _formatDateTime(provider.lastScrobbledAt!),
            ),
            const SizedBox(height: 8),
          ],
          _InfoRow(
            label: AppLocale.tr('scrobbled_count'),
            value: '${provider.scrobbleCount}',
          ),
          if (provider.recentHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(AppLocale.tr('recent_scrobbles')),
            const SizedBox(height: 8),
            ...provider.recentHistory.take(10).map((item) {
              return _ScrobbleHistoryTile(item: item);
            }),
          ],
          if (provider.error != null) ...[
            const SizedBox(height: 16),
            Text(provider.error!, style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ScrobbleHistoryTile extends StatelessWidget {
  final ScrobbleItem item;

  const _ScrobbleHistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isNotEmpty ? item.title : item.videoId,
                  style: TextStyle(color: MelodiTheme.onSurface, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.artists.isNotEmpty)
                  Text(
                    item.artists,
                    style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (item.spotifyTrackId != null)
            Icon(Icons.check_circle, color: MelodiTheme.primaryGreen, size: 16),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(color: MelodiTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
          ),
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
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15)),
      subtitle: Text(
        currentColor != null
            ? '#${currentColor!.value.toRadixString(16).substring(2).toUpperCase()}'
            : AppLocale.tr('default_color'),
        style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 12),
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
              color: MelodiTheme.textMuted,
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
                border: Border.all(color: MelodiTheme.textMuted, width: 2),
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
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(label,
                style: TextStyle(
                    color: MelodiTheme.onSurface,
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
                            ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
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

class _LosslessDownloadsSection extends StatefulWidget {
  @override
  State<_LosslessDownloadsSection> createState() =>
      _LosslessDownloadsSectionState();
}

class _LosslessDownloadsSectionState extends State<_LosslessDownloadsSection> {
  bool _losslessQuality = true;
  String _coverResolution = 'high';
  bool _embedMetadata = true;
  bool _loudnessNorm = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    final lossless = await db.getSetting('lossless_quality');
    final cover = await db.getSetting('cover_resolution');
    final embed = await db.getSetting('embed_metadata');
    final loudness = await db.getSetting('loudness_norm');
    if (mounted) {
      setState(() {
        _losslessQuality = lossless != 'false';
        _coverResolution = cover ?? 'high';
        _embedMetadata = embed != 'false';
        _loudnessNorm = loudness == 'true';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.high_quality_rounded,
          iconColor: Colors.amber,
          title: AppLocale.tr('lossless_quality'),
          subtitle: AppLocale.tr('lossless'),
          trailing: Switch(
            value: _losslessQuality,
            onChanged: (v) {
              setState(() => _losslessQuality = v);
              DatabaseService.instance
                  .setSetting('lossless_quality', v.toString());
            },
            activeColor: MelodiTheme.primaryGreen,
          ),
          onTap: () {
            final v = !_losslessQuality;
            setState(() => _losslessQuality = v);
            DatabaseService.instance
                .setSetting('lossless_quality', v.toString());
          },
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.image_rounded,
          iconColor: Colors.indigo,
          title: AppLocale.tr('cover_resolution'),
          subtitle: _coverResolution == 'high'
              ? AppLocale.tr('high')
              : _coverResolution == 'medium'
                  ? AppLocale.tr('medium')
                  : AppLocale.tr('low'),
          trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
          onTap: () => _showResolutionPicker(context),
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.description_rounded,
          iconColor: Colors.teal,
          title: AppLocale.tr('embed_metadata'),
          subtitle: AppLocale.tr('metadata_backfill'),
          trailing: Switch(
            value: _embedMetadata,
            onChanged: (v) {
              setState(() => _embedMetadata = v);
              DatabaseService.instance
                  .setSetting('embed_metadata', v.toString());
            },
            activeColor: MelodiTheme.primaryGreen,
          ),
          onTap: () {
            final v = !_embedMetadata;
            setState(() => _embedMetadata = v);
            DatabaseService.instance
                .setSetting('embed_metadata', v.toString());
          },
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.volume_up_rounded,
          iconColor: Colors.orange,
          title: AppLocale.tr('loudness_norm'),
          subtitle: AppLocale.tr('audio'),
          trailing: Switch(
            value: _loudnessNorm,
            onChanged: (v) {
              setState(() => _loudnessNorm = v);
              DatabaseService.instance
                  .setSetting('loudness_norm', v.toString());
            },
            activeColor: MelodiTheme.primaryGreen,
          ),
          onTap: () {
            final v = !_loudnessNorm;
            setState(() => _loudnessNorm = v);
            DatabaseService.instance
                .setSetting('loudness_norm', v.toString());
          },
        ),
      ],
    );
  }

  void _showResolutionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
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
                color: MelodiTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(AppLocale.tr('cover_resolution'),
                style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...[
              (AppLocale.tr('high'), 'high'),
              (AppLocale.tr('medium'), 'medium'),
              (AppLocale.tr('low'), 'low'),
            ].map((entry) {
              final selected = _coverResolution == entry.$2;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? MelodiTheme.primaryGreen
                      : MelodiTheme.textMuted,
                ),
                title: Text(entry.$1,
                    style: TextStyle(color: MelodiTheme.onSurface)),
                onTap: () {
                  setState(() => _coverResolution = entry.$2);
                  DatabaseService.instance
                      .setSetting('cover_resolution', entry.$2);
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
          style: const TextStyle(
              color: Color(0xFFbccbb9), fontSize: 12));
    } else if (subtitle is Widget) {
      subtitleWidget = subtitle as Widget;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF201f1f),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Color(0xFFe5e2e1), fontSize: 15)),
        subtitle: subtitleWidget,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _LibraryHealthSettingsTile extends StatefulWidget {
  @override
  State<_LibraryHealthSettingsTile> createState() => _LibraryHealthSettingsTileState();
}

class _LibraryHealthSettingsTileState extends State<_LibraryHealthSettingsTile> {
  double? _cachedScore;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = LibraryHealthService();
    await svc.scanLibrary();
    if (mounted) {
      setState(() {
        _cachedScore = svc.getHealthScore();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.favorite_rounded,
      iconColor: Colors.pink,
      title: AppLocale.tr('library_health'),
      subtitle: _loading
          ? AppLocale.tr('scan_library')
          : _cachedScore != null
              ? '${AppLocale.tr('health_score')}: ${_cachedScore!.round()}%'
              : AppLocale.tr('scan_library'),
      trailing: _loading
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.primaryGreen),
            )
          : Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LibraryHealthScreen()),
      ),
    );
  }
}

class _AudioEffectsPage extends StatelessWidget {
  const _AudioEffectsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: const Text('Audio Effects'),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsTile(
            icon: Icons.spatial_audio_off,
            iconColor: Colors.purple,
            title: 'Spatial Audio',
            subtitle: '3D sound positioning',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: const Color(0xFF53e076),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.waves,
            iconColor: Colors.blue,
            title: 'Reverb',
            subtitle: 'Add room ambience effects',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: const Color(0xFF53e076),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.graphic_eq,
            iconColor: Colors.orange,
            title: 'Bass Boost',
            subtitle: 'Enhance low frequency response',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: const Color(0xFF53e076),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.hearing,
            iconColor: Colors.teal,
            title: 'Virtualizer',
            subtitle: 'Simulate surround sound through headphones',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: const Color(0xFF53e076),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceControlPage extends StatelessWidget {
  const _VoiceControlPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: const Text('Voice Control'),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsTile(
            icon: Icons.mic,
            iconColor: Colors.orange,
            title: 'Siri Integration',
            subtitle: 'Control playback with Siri commands',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: const Color(0xFF53e076),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.shortcut,
            iconColor: Colors.teal,
            title: 'Custom Shortcuts',
            subtitle: 'Create custom voice commands',
            trailing: Icon(Icons.chevron_right, color: MelodiTheme.textMuted),
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.record_voice_over,
            iconColor: Colors.indigo,
            title: 'Voice Feedback',
            subtitle: 'Announce track changes and status',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: const Color(0xFF53e076),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastSubscriptionsPage extends StatelessWidget {
  const _PodcastSubscriptionsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: const Text('Podcasts'),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones, size: 64, color: MelodiTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'No podcast subscriptions yet',
              style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse and subscribe to your favorite podcasts',
              style: TextStyle(color: MelodiTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Browse Podcasts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53e076),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudiobookLibraryPage extends StatefulWidget {
  const _AudiobookLibraryPage();

  @override
  State<_AudiobookLibraryPage> createState() => _AudiobookLibraryPageState();
}

class _AudiobookLibraryPageState extends State<_AudiobookLibraryPage> {
  final AudiobookService _service = AudiobookService.instance;
  List<Audiobook> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await _service.getAllAudiobooks();
    if (mounted) setState(() { _books = books; _loading = false; });
  }

  Future<void> _importFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    final book = await _service.loadAudiobook(path);
    if (book == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ses dosyası bulunamadı'), backgroundColor: MelodiTheme.errorRed),
      );
      return;
    }
    await _service.saveAudiobook(book);
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${book.title} eklendi'), backgroundColor: MelodiTheme.primaryGreen),
    );
  }

  Future<void> _deleteBook(Audiobook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text('Sil', style: TextStyle(color: MelodiTheme.onSurface)),
        content: Text('${book.title} silinecek. Emin misiniz?', style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: MelodiTheme.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sil', style: TextStyle(color: MelodiTheme.errorRed))),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteAudiobook(book.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: const Text('Audiobooks'),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _importFolder,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: MelodiTheme.primaryGreen))
          : _books.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book, size: 64, color: MelodiTheme.textMuted),
                      const SizedBox(height: 16),
                      Text('Sesli kitap bulunamadı', style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Klasör içe aktararak başlayın', style: TextStyle(color: MelodiTheme.textMuted, fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _importFolder,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Klasör İçe Aktar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MelodiTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final progress = (book.progress * 100).toInt();
                    return Dismissible(
                      key: Key(book.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: MelodiTheme.errorRed,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteBook(book),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MelodiTheme.containerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: MelodiTheme.primaryGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.menu_book, color: MelodiTheme.primaryGreen, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(book.title, style: TextStyle(color: MelodiTheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('${book.author} · ${book.chapters.length} bölüm', style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
                                  if (progress > 0) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: book.progress,
                                        backgroundColor: MelodiTheme.outlineVariant,
                                        valueColor: AlwaysStoppedAnimation(MelodiTheme.primaryGreen),
                                        minHeight: 4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${(progress * 100).toInt()}% tamamlandı', style: TextStyle(color: MelodiTheme.textMuted, fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

void _showEqPresetsDialog(BuildContext context) {
  final presets = [
    ('Flat', Icons.equalizer),
    ('Bass Boost', Icons.graphic_eq),
    ('Treble Boost', Icons.trending_up),
    ('Vocal', Icons.mic),
    ('Rock', Icons.music_note),
    ('Jazz', Icons.piano),
    ('Classical', Icons.queue_music),
    ('Electronic', Icons.electric_bolt),
    ('Podcast', Icons.headphones),
  ];
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF201f1f),
      title: Text('EQ Presets',
          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: presets.length,
          itemBuilder: (ctx, i) {
            final (name, icon) = presets[i];
            return ListTile(
              leading: Icon(icon, color: const Color(0xFF53e076), size: 20),
              title: Text(name, style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15)),
              onTap: () {
                DatabaseService.instance.setSetting('eq_preset', name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('EQ preset set to $name'),
                    backgroundColor: const Color(0xFF53e076),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
        ),
      ],
    ),
  );
}

void _showAirPlayDevicesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF201f1f),
      title: Text('AirPlay',
          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.speaker, color: const Color(0xFF53e076), size: 20),
            title: Text('No devices found', style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 15)),
            subtitle: Text('Make sure AirPlay devices are on the same network',
                style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Close', style: TextStyle(color: MelodiTheme.primaryGreen)),
        ),
      ],
    ),
  );
}

void _showWidgetConfigDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF201f1f),
      title: Text('Widget Configuration',
          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose which widgets to display on your home screen:',
              style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 16),
          _widgetOption(ctx, 'Now Playing', Icons.music_note, true),
          _widgetOption(ctx, 'Quick Play', Icons.play_arrow, false),
          _widgetOption(ctx, 'Favorites', Icons.favorite, false),
          _widgetOption(ctx, 'Recently Played', Icons.history, false),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Done', style: TextStyle(color: MelodiTheme.primaryGreen)),
        ),
      ],
    ),
  );
}

Widget _widgetOption(BuildContext ctx, String name, IconData icon, bool enabled) {
  return ListTile(
    leading: Icon(icon, color: const Color(0xFF53e076), size: 20),
    title: Text(name, style: const TextStyle(color: Color(0xFFe5e2e1), fontSize: 15)),
    trailing: Switch(
      value: enabled,
      onChanged: (v) {},
      activeColor: const Color(0xFF53e076),
    ),
  );
}
