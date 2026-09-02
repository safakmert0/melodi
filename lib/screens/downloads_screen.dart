import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/download_provider.dart';
import '../providers/library_provider.dart';
import '../services/notification_service.dart';
import '../models/song_model.dart';
import '../widgets/downloads/download_header.dart';
import '../widgets/downloads/download_list_item.dart';
import '../widgets/downloads/download_empty_state.dart';

/// Downloads screen - complete offline download management
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadProvider = context.watch<DownloadProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: _buildAppBar(context, isDark),
      body: Column(
        children: [
          // Tab selector
          _buildTabBar(context, isDark),

          // Content area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllDownloadsTab(context, downloadProvider, isDark),
                _buildCompletedTab(context, downloadProvider, isDark),
                _buildFailedTab(context, downloadProvider, isDark),
              ],
            ),
          ),
        ],
      ),
      // Floating action button for new downloads
      floatingActionButton: _buildFAB(context, downloadProvider, isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: isDark
          ? Colors.grey[900]
          : Colors.white,
      elevation: 0,
      title: const Text(
        'İndirmeler',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Ara',
          onPressed: () {
            // Search downloads
          },
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.green,
        labelColor: Colors.green,
        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
        tabs: const [
          Tab(text: 'Tümü'),
          Tab(text: 'Tamamlanmış'),
          Tab(text: 'Başarısız'),
        ],
      ),
    );
  }

  Widget _buildAllDownloadsTab(
      BuildContext context,
      DownloadProvider downloadProvider,
      bool isDark,
      ) {
    final tasks = downloadProvider.tasks;

    if (tasks.isEmpty) {
      return const DownloadEmptyState(
        icon: Icons.download,
        message: 'Henüz indirme yok',
      );
    }

    return NotificationListener<DownloadProvider>(
      onNotification: (notification) {
        // Handle download updates
        return true;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          // Refresh downloads
          // downloadProvider.refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Stats header
            SliverToBoxAdapter(
              child: _buildDownloadStats(tasks, isDark),
            ),

            // Downloads list
            if (tasks.isNotEmpty)
              SliverList(
                delegate: SliverBuilder.builder(
                  builder: (context, index) {
                    if (index >= tasks.length) return null;
                    final task = tasks[index];
                    return DownloadListItem(task: task);
                  },
                  count: tasks.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTab(
      BuildContext context,
      DownloadProvider downloadProvider,
      bool isDark,
      ) {
    final completed = downloadProvider.completedDownloads;

    if (completed.isEmpty) {
      return const DownloadEmptyState(
        icon: Icons.check_circle,
        message: 'Tüm indirmeler tamamlandı',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh completed downloads
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildDownloadStats(completed, isDark),
          ),
          SliverList(
            delegate: SliverBuilder.builder(
              builder: (context, index) {
                if (index >= completed.length) return null;
                final task = completed[index];
                return DownloadListItem(task: task, showCheckmark: true);
              },
              count: completed.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedTab(
      BuildContext context,
      DownloadProvider downloadProvider,
      bool isDark,
      ) {
    final failed = downloadProvider.failedDownloads;

    if (failed.isEmpty) {
      return const DownloadEmptyState(
        icon: Icons.error,
        message: 'Başarısız indirme yok',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh failed downloads
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildDownloadStats(failed, isDark),
          ),
          SliverList(
            delegate: SliverBuilder.builder(
              builder: (context, index) {
                if (index >= failed.length) return null;
                final task = failed[index];
                return DownloadListItem(task: task, showError: true);
              },
              count: failed.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadStats(
      List<DownloadTask> tasks, bool isDark) {
    final active = tasks.where((t) => t.state == DownloadState.downloading || t.state == DownloadState.pending).toList();
    final completed = tasks.where((t) => t.state == DownloadState.completed).toList();
    final failed = tasks.where((t) => t.state == DownloadState.failed).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Aktif',
            count: active.length,
            color: Colors.green,
            isDark: isDark,
          ),
          _StatItem(
            label: 'Tamam',
            count: completed.length,
            color: Colors.blue,
            isDark: isDark,
          ),
          _StatItem(
            label: 'Başarısız',
            count: failed.length,
            color: Colors.red,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(
      BuildContext context,
      DownloadProvider downloadProvider,
      bool isDark,
      ) {
    final fabColor = isDark ? Colors.green : Colors.green;

    return FloatingActionButton(
      onPressed: () {
        // Show add download dialog
        _showAddDownloadDialog(context);
      },
      backgroundColor: fabColor,
      child: const Icon(Icons.add),
    );
  }

  void _showAddDownloadDialog(BuildContext context) {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final SpotifyTrackIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şarkı Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Şarkı Başlığı',
                hintText: 'Şarkı adını girin',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(
                labelText: 'Sanatçı',
                hintText: 'Sanatçı adını girin',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: SpotifyTrackIdController,
              decoration: const InputDecoration(
                labelText: 'Spotify Track ID (İsteğe bağlı)',
                hintText: 'Örn: 4iV5W9uYEdYVGU3cFz7Gu3',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final artist = artistController.text.trim();
              final spotifyTrackId = SpotifyTrackIdController.text.trim();

              if (title.isNotEmpty && artist.isNotEmpty) {
                downloadProvider.enqueueTrack(
                  spotifyTrackId: spotifyTrackId.isNotEmpty ? spotifyTrackId : '',
                  title: title,
                  artist: artist,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

/// Stat item widget for download stats
class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? color.withOpacity(0.1) : color.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Download list item widget
class DownloadListItem extends StatelessWidget {
  final DownloadTask task;
  final bool showCheckmark;
  final bool showError;

  const DownloadListItem({
    required this.task,
    this.showCheckmark = false,
    this.showError = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blur: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Checkmark for completed
            if (showCheckmark)
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              )
            else if (showError)
              Icon(
                Icons.error,
                color: Colors.red,
                size: 24,
              )
            else
              const SizedBox.shrink(),

            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: task.albumArt != null
                  ? Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.music_note,
                        size: 24,
                        color: Colors.grey[600],
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[300],
                    ),
            ),
            const SizedBox(width: 12),

            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.artist,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Progress and state
            _DownloadProgressBar(task: task),
          ],
        ),
      ),
    );
  }
}

/// Download progress bar widget
class _DownloadProgressBar extends StatelessWidget {
  final DownloadTask task;

  const _DownloadProgressBar({
    required this.task,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: task.progress,
          color: task.state == DownloadState.downloading
              ? Colors.green
              : task.state == DownloadState.pending
                  ? Colors.amber
                  : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            _getProgressText(),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _getProgressText() {
    switch (task.state) {
      case DownloadState.pending:
        return 'Bekliyor';
      case DownloadState.downloading:
        return '${(task.progress * 100).toInt()}%';
      case DownloadState.completed:
        return 'Tamam';
      case DownloadState.failed:
        return 'Başarısız';
      default:
        return '-';
    }
  }
}

/// Empty state widget for downloads
class DownloadEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const DownloadEmptyState({
    required this.icon,
    required this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;

    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}