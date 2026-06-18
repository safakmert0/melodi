import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/database_service.dart';
import '../providers/download_provider.dart';
import '../providers/metadata_provider.dart';
import '../screens/library_health_screen.dart';
import '../screens/failed_downloads_screen.dart';

enum BannerType { info, warning, error }

class BannerDismiss {
  static Future<bool> isDismissed(String key) async {
    final db = DatabaseService.instance;
    final data = await db.getSetting('banner_dismiss_$key');
    if (data == null) return false;
    final parts = data.split('|');
    if (parts.length != 2) return false;
    final expiry = DateTime.tryParse(parts[1]);
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) return true;
    return true;
  }

  static Future<void> dismiss(String key, {Duration expiry = const Duration(days: 1)}) async {
    final db = DatabaseService.instance;
    final expiryStr = DateTime.now().add(expiry).toIso8601String();
    await db.setSetting('banner_dismiss_$key', 'dismissed|$expiryStr');
  }
}

class HomeBanners extends StatelessWidget {
  const HomeBanners({super.key});

  @override
  Widget build(BuildContext context) {
    final md = context.watch<MetadataProvider>();
    final dp = context.watch<DownloadProvider>();

    return Column(
      children: [
        _MetadataBackfillBanner(md: md),
        _LyricsBackfillBanner(md: md),
        const _WaitingForLosslessBanner(),
        _FailedDownloadsBanner(dp: dp),
        const _LibraryHealthBanner(),
      ],
    );
  }
}

class _MetadataBackfillBanner extends StatefulWidget {
  final MetadataProvider md;
  const _MetadataBackfillBanner({required this.md});

  @override
  State<_MetadataBackfillBanner> createState() => _MetadataBackfillBannerState();
}

class _MetadataBackfillBannerState extends State<_MetadataBackfillBanner> {
  bool _dismissed = false;
  int _trackCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    _dismissed = await BannerDismiss.isDismissed('metadata_backfill');
    final missing = await db.getTracksMissingArt();
    _trackCount = missing.length;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _trackCount == 0) return const SizedBox.shrink();

    return _BannerCard(
      type: BannerType.info,
      icon: Icons.image_rounded,
      message: AppLocale.tr('x_tracks_need_art').replaceAll('{count}', '$_trackCount'),
      actionLabel: 'Start',
      onAction: () {
        widget.md.startBackfillAlbumArt();
        _dismiss();
      },
      onDismiss: _dismiss,
    );
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    BannerDismiss.dismiss('metadata_backfill');
  }
}

class _LyricsBackfillBanner extends StatefulWidget {
  final MetadataProvider md;
  const _LyricsBackfillBanner({required this.md});

  @override
  State<_LyricsBackfillBanner> createState() => _LyricsBackfillBannerState();
}

class _LyricsBackfillBannerState extends State<_LyricsBackfillBanner> {
  bool _dismissed = false;
  int _trackCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    _dismissed = await BannerDismiss.isDismissed('lyrics_backfill');
    final tracks = await db.rawQuery('''
      SELECT COUNT(*) as count FROM songs s
      WHERE (s.lyrics IS NULL OR s.lyrics = '')
      AND NOT EXISTS (SELECT 1 FROM track_lyrics tl WHERE tl.trackId = s.id)
    ''');
    _trackCount = (tracks.first['count'] as int?) ?? 0;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _trackCount == 0) return const SizedBox.shrink();

    return _BannerCard(
      type: BannerType.info,
      icon: Icons.lyrics_rounded,
      message: AppLocale.tr('x_tracks_need_lyrics').replaceAll('{count}', '$_trackCount'),
      actionLabel: 'Start',
      onAction: () {
        widget.md.startBackfillLyrics();
        _dismiss();
      },
      onDismiss: _dismiss,
    );
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    BannerDismiss.dismiss('lyrics_backfill');
  }
}

class _WaitingForLosslessBanner extends StatefulWidget {
  @override
  State<_WaitingForLosslessBanner> createState() => _WaitingForLosslessBannerState();
}

class _WaitingForLosslessBannerState extends State<_WaitingForLosslessBanner> {
  bool _dismissed = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _dismissed = await BannerDismiss.isDismissed('waiting_lossless');
    final db = DatabaseService.instance;
    try {
      final result = await db.rawQuery("SELECT COUNT(*) as count FROM pending_lossless");
      _count = (result.first['count'] as int?) ?? 0;
    } catch (_) {
      _count = 0;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _count == 0) return const SizedBox.shrink();

    return _BannerCard(
      type: BannerType.warning,
      icon: Icons.hourglass_empty_rounded,
      message: AppLocale.tr('x_tracks_waiting_lossless').replaceAll('{count}', '$_count'),
      onDismiss: () {
        setState(() => _dismissed = true);
        BannerDismiss.dismiss('waiting_lossless');
      },
    );
  }
}

class _FailedDownloadsBanner extends StatelessWidget {
  final DownloadProvider dp;
  const _FailedDownloadsBanner({required this.dp});

  @override
  Widget build(BuildContext context) {
    if (dp.failedCount == 0) return const SizedBox.shrink();

    return _BannerCard(
      type: BannerType.error,
      icon: Icons.error_outline_rounded,
      message: AppLocale.tr('x_downloads_failed').replaceAll('{count}', '${dp.failedCount}'),
      actionLabel: 'View',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FailedDownloadsScreen()),
        );
      },
    );
  }
}

class _LibraryHealthBanner extends StatefulWidget {
  @override
  State<_LibraryHealthBanner> createState() => _LibraryHealthBannerState();
}

class _LibraryHealthBannerState extends State<_LibraryHealthBanner> {
  int _issueCount = 0;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _dismissed = await BannerDismiss.isDismissed('library_health_banner');
    final db = DatabaseService.instance;
    final missingArt = await db.getTracksMissingArt();
    final missingMeta = await db.getTracksMissingMetadata();
    _issueCount = missingArt.length + missingMeta.length;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _issueCount == 0) return const SizedBox.shrink();

    return _BannerCard(
      type: BannerType.warning,
      icon: Icons.favorite_border_rounded,
      message: '$_issueCount ${AppLocale.tr('issues_found')}',
      actionLabel: AppLocale.tr('library_health'),
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LibraryHealthScreen()),
        );
      },
      onDismiss: () => setState(() => _dismissed = true),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerType type;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const _BannerCard({
    required this.type,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  Color get _backgroundColor {
    switch (type) {
      case BannerType.info: return const Color(0xFF1A5276);
      case BannerType.warning: return const Color(0xFF7D6608);
      case BannerType.error: return const Color(0xFF922B21);
    }
  }

  Color get _iconColor {
    switch (type) {
      case BannerType.info: return const Color(0xFF5DADE2);
      case BannerType.warning: return const Color(0xFFF4D03F);
      case BannerType.error: return const Color(0xFFE74C3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppConstants.animationDuration,
      curve: Curves.easeInOut,
      child: Container(
        color: _backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: _iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7), size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
