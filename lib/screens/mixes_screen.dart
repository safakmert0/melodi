import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/mix_provider.dart';

class MixesScreen extends StatefulWidget {
  const MixesScreen({super.key});

  @override
  State<MixesScreen> createState() => _MixesScreenState();
}

class _MixesScreenState extends State<MixesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mixProvider = context.read<MixProvider>();
      if (mixProvider.dailyMix.isEmpty) {
        mixProvider.generateAllMixes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          AppLocale.tr('mixes'),
          style: TextStyle(
            color: MelodiTheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: MelodiTheme.primaryGreen),
            tooltip: AppLocale.tr('regenerate'),
            onPressed: () => context.read<MixProvider>().generateAllMixes(),
          ),
        ],
      ),
      body: Consumer<MixProvider>(
        builder: (context, mixProvider, _) {
          if (mixProvider.isLoading && mixProvider.dailyMix.isEmpty) {
            return _buildShimmerLoading();
          }
          if (mixProvider.error != null && mixProvider.dailyMix.isEmpty) {
            return _buildError(mixProvider.error!);
          }
          return RefreshIndicator(
            onRefresh: () => mixProvider.generateAllMixes(),
            color: MelodiTheme.primaryGreen,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (mixProvider.dailyMix.isNotEmpty)
                  _buildDailyMixSection(mixProvider),
                if (mixProvider.releaseRadar.isNotEmpty)
                  _buildReleaseRadarSection(mixProvider),
                if (mixProvider.discoverWeekly.isNotEmpty)
                  _buildDiscoverWeeklySection(mixProvider),
                if (mixProvider.lastGenerated != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Text(
                        '${AppLocale.tr('generated_at')}: ${_formatDate(mixProvider.lastGenerated!)}',
                        style: TextStyle(
                          color: MelodiTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 80,
          decoration: BoxDecoration(
            color: MelodiTheme.containerLow,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: MelodiTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              AppLocale.tr('no_mixes_yet'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  context.read<MixProvider>().generateAllMixes(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocale.tr('regenerate')),
              style: FilledButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMixSection(MixProvider mixProvider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: AppLocale.tr('daily_mix'),
            subtitle: '${mixProvider.dailyMix.length} ${AppLocale.tr('songs')}',
            onRegenerate: () => mixProvider.refreshDailyMix(),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: mixProvider.dailyMix.length,
              itemBuilder: (context, index) {
                final track = mixProvider.dailyMix[index];
                return _TrackCard(
                  title: track['title'] as String? ?? '',
                  artist: track['artist'] as String? ?? '',
                  imageUrl: track['imageUrl'] as String?,
                  onTap: () => _showTrackInfo(track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseRadarSection(MixProvider mixProvider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: AppLocale.tr('release_radar'),
            subtitle:
                '${mixProvider.releaseRadar.length} ${AppLocale.tr('songs')}',
            onRegenerate: () => mixProvider.refreshReleaseRadar(),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mixProvider.releaseRadar.length,
            itemBuilder: (context, index) {
              final track = mixProvider.releaseRadar[index];
              return _TrackListTile(
                title: track['title'] as String? ?? '',
                artist: track['artist'] as String? ?? '',
                album: track['album'] as String? ?? '',
                imageUrl: track['imageUrl'] as String?,
                durationMs: track['durationMs'] as int? ?? 0,
                onTap: () => _showTrackInfo(track),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverWeeklySection(MixProvider mixProvider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: AppLocale.tr('discover_weekly'),
            subtitle:
                '${mixProvider.discoverWeekly.length} ${AppLocale.tr('songs')}',
            onRegenerate: () => mixProvider.refreshDiscoverWeekly(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: mixProvider.discoverWeekly.length,
              itemBuilder: (context, index) {
                final track = mixProvider.discoverWeekly[index];
                return _GridTrackCard(
                  title: track['title'] as String? ?? '',
                  artist: track['artist'] as String? ?? '',
                  imageUrl: track['imageUrl'] as String?,
                  onTap: () => _showTrackInfo(track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackInfo(Map<String, dynamic> track) {
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
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: track['imageUrl'] != null
                    ? Image.network(
                        track['imageUrl'] as String,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 200,
                          color: MelodiTheme.containerLow,
                          child: Icon(Icons.music_note_rounded,
                              size: 64, color: MelodiTheme.textMuted),
                        ),
                      )
                    : Container(
                        width: 200,
                        height: 200,
                        color: MelodiTheme.containerLow,
                        child: Icon(Icons.music_note_rounded,
                            size: 64, color: MelodiTheme.textMuted),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                track['title'] as String? ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MelodiTheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                track['artist'] as String? ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              if ((track['album'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  track['album'] as String? ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MelodiTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRegenerate;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: MelodiTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRegenerate != null)
            GestureDetector(
              onTap: onRegenerate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MelodiTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 14, color: MelodiTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      AppLocale.tr('regenerate'),
                      style: TextStyle(
                        color: MelodiTheme.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final VoidCallback onTap;

  const _TrackCard({
    required this.title,
    required this.artist,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: MelodiTheme.containerLow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MelodiTheme.containerLow,
                          child: Icon(Icons.music_note_rounded,
                              size: 48, color: MelodiTheme.textMuted),
                        ),
                      )
                    : Container(
                        color: MelodiTheme.containerLow,
                        child: Icon(Icons.music_note_rounded,
                            size: 48, color: MelodiTheme.textMuted),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MelodiTheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackListTile extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final String? imageUrl;
  final int durationMs;
  final VoidCallback onTap;

  const _TrackListTile({
    required this.title,
    required this.artist,
    required this.album,
    this.imageUrl,
    required this.durationMs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr =
        '${(durationMs ~/ 60000)}:${((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0')}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: MelodiTheme.containerLow,
                        child: Icon(Icons.music_note_rounded,
                            size: 24, color: MelodiTheme.textMuted),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: MelodiTheme.containerLow,
                      child: Icon(Icons.music_note_rounded,
                          size: 24, color: MelodiTheme.textMuted),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MelodiTheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$artist • $album',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              durationStr,
              style: TextStyle(
                color: MelodiTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _GridTrackCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final VoidCallback onTap;

  const _GridTrackCard({
    required this.title,
    required this.artist,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: MelodiTheme.containerLow,
                        child: Icon(Icons.music_note_rounded,
                            size: 48, color: MelodiTheme.textMuted),
                      ),
                    )
                  : Container(
                      color: MelodiTheme.containerLow,
                      child: Icon(Icons.music_note_rounded,
                          size: 48, color: MelodiTheme.textMuted),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MelodiTheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
