import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/download_provider.dart';
import '../services/download_manager.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('downloads')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, provider, _) {
          final activeCount = provider.activeCount;
          return Column(
            children: [
              Container(
                color: MelodiTheme.containerLow,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: MelodiTheme.primaryGreen,
                  labelColor: MelodiTheme.primaryGreen,
                  unselectedLabelColor: MelodiTheme.textMuted,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocale.tr('active')),
                          if (activeCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MelodiTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$activeCount',
                                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: AppLocale.tr('completed')),
                    Tab(text: AppLocale.tr('failed')),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ActiveTab(),
                    _CompletedTab(),
                    _FailedTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final active = provider.activeDownloads;
        if (active.isEmpty) {
          return _buildEmptyState(context, AppLocale.tr('no_downloads'));
        }
        return RefreshIndicator(
          onRefresh: () async {},
          color: MelodiTheme.primaryGreen,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: active.length,
            itemBuilder: (context, index) {
              final task = active[index];
              return _ActiveDownloadTile(task: task);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_rounded, size: 64, color: MelodiTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 16),
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
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MelodiTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.download_rounded, color: MelodiTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: MelodiTheme.errorRed, size: 18),
                    onPressed: () => provider.cancelTask(task.id),
                    tooltip: AppLocale.tr('cancel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 4,
                backgroundColor: MelodiTheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(MelodiTheme.primaryGreen),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(task.progress * 100).toInt()}%',
                  style: TextStyle(color: MelodiTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  provider.stateText(task),
                  style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final completed = provider.completedDownloads;
        if (completed.isEmpty) {
          return _buildEmptyState(context, AppLocale.tr('no_downloads'));
        }
        return RefreshIndicator(
          onRefresh: () async {},
          color: MelodiTheme.primaryGreen,
          child: Column(
            children: [
              if (completed.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '${completed.length} ${AppLocale.tr('completed')}',
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => provider.clearCompleted(),
                        icon: Icon(Icons.delete_sweep_rounded, size: 18, color: MelodiTheme.errorRed),
                        label: Text(AppLocale.tr('clear_all'),
                            style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: completed.length,
                  itemBuilder: (context, index) {
                    final task = completed[index];
                    return _CompletedDownloadTile(task: task);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done_rounded, size: 64, color: MelodiTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CompletedDownloadTile extends StatelessWidget {
  final DownloadTask task;
  const _CompletedDownloadTile({required this.task});

  String _formatSize(String? filePath) {
    if (filePath == null) return '';
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        if (bytes < 1024 * 1024 * 1024) {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: MelodiTheme.errorRed,
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => context.read<DownloadProvider>().cancelTask(task.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: MelodiTheme.containerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MelodiTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_circle_rounded, color: MelodiTheme.primaryGreen, size: 22),
          ),
          title: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  task.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
              if (_formatSize(task.filePath).isNotEmpty) ...[
                Text(' · ', style: TextStyle(color: MelodiTheme.textMuted, fontSize: 11)),
                Text(
                  _formatSize(task.filePath),
                  style: TextStyle(color: MelodiTheme.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final failed = provider.failedDownloads;
        if (failed.isEmpty) {
          return _buildEmptyState(context, AppLocale.tr('no_failed_downloads'));
        }
        return RefreshIndicator(
          onRefresh: () async {},
          color: MelodiTheme.primaryGreen,
          child: Column(
            children: [
              if (failed.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '${failed.length} ${AppLocale.tr('failed')}',
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => provider.retryAllFailed(),
                        icon: Icon(Icons.refresh_rounded, size: 18, color: MelodiTheme.primaryGreen),
                        label: Text(AppLocale.tr('retry_all'),
                            style: TextStyle(color: MelodiTheme.primaryGreen, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => provider.clearFailed(),
                        icon: Icon(Icons.delete_sweep_rounded, size: 18, color: MelodiTheme.errorRed),
                        label: Text(AppLocale.tr('clear_all'),
                            style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: failed.length,
                  itemBuilder: (context, index) {
                    final task = failed[index];
                    return _FailedDownloadTile(task: task);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: MelodiTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FailedDownloadTile extends StatelessWidget {
  final DownloadTask task;
  const _FailedDownloadTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DownloadProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: MelodiTheme.errorRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.error_rounded, color: MelodiTheme.errorRed, size: 22),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15),
        ),
        subtitle: Text(
          task.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: MelodiTheme.primaryGreen, size: 20),
              onPressed: () => provider.retryTask(task.id),
              tooltip: AppLocale.tr('retry'),
            ),
            IconButton(
              icon: Icon(Icons.close, color: MelodiTheme.textMuted, size: 20),
              onPressed: () => provider.cancelTask(task.id),
              tooltip: AppLocale.tr('clear'),
            ),
          ],
        ),
      ),
    );
  }
}
