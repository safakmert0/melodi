import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/download_provider.dart';
import '../services/download_manager.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: MelodiTheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppLocale.tr('downloads'), style: MelodiTheme.heading(size: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: MelodiTheme.onSurfaceVariant, size: 22),
            onPressed: () {},
          ),
          Container(
            width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: MelodiTheme.containerHigh),
            child: const Icon(Icons.person, size: 20, color: MelodiTheme.onSurfaceVariant),
          ),
        ],
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, provider, _) {
          final active = provider.activeDownloads;
          final completed = provider.completedDownloads;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildStorageCard()),
              if (active.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('In Progress (${active.length})', style: MelodiTheme.heading(size: 18)),
                        TextButton(
                          onPressed: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: MelodiTheme.onSurfaceVariant),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text('Pause All', style: const TextStyle(
                              fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface,
                              fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (context, i) => _ActiveDownloadTile(task: active[i]),
                  childCount: active.length)),
              ],
              if (completed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Downloaded', style: MelodiTheme.heading(size: 18)),
                        const Icon(Icons.filter_list_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
                      ],
                    ),
                  ),
                ),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (context, i) => _DownloadedTile(task: completed[i]),
                  childCount: completed.length)),
              ],
              if (active.isEmpty && completed.isEmpty)
                SliverFillRemaining(child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded, size: 64, color: MelodiTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(AppLocale.tr('no_downloads'), style: const TextStyle(
                        color: MelodiTheme.onSurfaceVariant, fontSize: 16)),
                    ],
                  ),
                )),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStorageCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MelodiTheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEVICE STORAGE', style: MelodiTheme.label(letterSpacing: 0.08)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('12.4 GB used', style: MelodiTheme.heading(size: 24)),
              const Spacer(),
              Text('of 128 GB', style: const TextStyle(
                fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 0.1, minHeight: 6,
              backgroundColor: MelodiTheme.surfaceBright,
              valueColor: const AlwaysStoppedAnimation<Color>(MelodiTheme.primaryGreen)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(
                shape: BoxShape.circle, color: MelodiTheme.primaryGreen)),
              const SizedBox(width: 6),
              Text('Music (4.2 GB)', style: const TextStyle(
                fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(width: 16),
              Container(width: 8, height: 8, decoration: BoxDecoration(
                shape: BoxShape.circle, color: MelodiTheme.surfaceBright)),
              const SizedBox(width: 6),
              const Text('Other', style: TextStyle(
                fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDownloadTile extends StatelessWidget {
  final DownloadTask task;
  const _ActiveDownloadTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DownloadProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: MelodiTheme.containerHigh),
                child: const Icon(Icons.download_rounded, color: MelodiTheme.primaryGreen, size: 24),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4)),
                ),
              ),
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  value: task.progress, strokeWidth: 2,
                  color: MelodiTheme.primaryGreen,
                  backgroundColor: Colors.transparent)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppConstants.fontFamily,
                        color: MelodiTheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500))),
                    Text('${(task.progress * 100).toInt()}%', style: const TextStyle(
                      fontFamily: AppConstants.fontFamily, color: MelodiTheme.primaryGreen,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text(task.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppConstants.fontFamily,
                    color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: task.progress, minHeight: 3,
                    backgroundColor: MelodiTheme.surfaceBright,
                    valueColor: const AlwaysStoppedAnimation<Color>(MelodiTheme.primaryGreen)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadedTile extends StatelessWidget {
  final DownloadTask task;
  const _DownloadedTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: MelodiTheme.containerHigh),
                child: const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant, size: 24),
              ),
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: MelodiTheme.primaryGreen),
                  child: const Icon(Icons.check, size: 12, color: MelodiTheme.background)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppConstants.fontFamily,
                    color: MelodiTheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                Text(task.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppConstants.fontFamily,
                    color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
