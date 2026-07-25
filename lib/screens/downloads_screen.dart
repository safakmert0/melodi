import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../services/database_service.dart';
import '../services/audio_quality_service.dart';
import '../services/download_manager.dart';
import '../services/storage_manager.dart';
import '../widgets/downloads/download_components.dart';
import 'audio_quality_screen.dart';
import 'settings_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  DownloadViewFilter _filter = DownloadViewFilter.all;
  final Set<String> _selectedIds = <String>{};
  late Future<_DownloadSnapshot> _snapshot;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _snapshot = _loadSnapshot();
  }

  Future<_DownloadSnapshot> _loadSnapshot() async {
    final storage = StorageManager.instance;
    final size = await storage.getLibrarySize();
    final path = await storage.getStorageLocation();
    final quality = await AudioQualityService().getDownloadQuality();
    return _DownloadSnapshot(size: size, path: path, quality: quality);
  }

  Future<void> _refreshSnapshot() async {
    final next = _loadSnapshot();
    setState(() => _snapshot = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final visible = _visibleTasks(provider);
        _selectedIds
            .removeWhere((id) => !provider.tasks.any((task) => task.id == id));
        return Scaffold(
          appBar: _buildAppBar(context, provider, visible),
          body: RefreshIndicator(
            onRefresh: _refreshSnapshot,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: FutureBuilder<_DownloadSnapshot>(
                    future: _snapshot,
                    builder: (context, snapshot) {
                      final details = snapshot.data;
                      return DownloadSummary(
                        activeCount: provider.activeCount,
                        completedCount: provider.completedCount,
                        failedCount: provider.failedCount,
                        storageLabel: details == null
                            ? 'Hesaplanıyor…'
                            : _formatBytes(details.size),
                        qualityLabel: details == null
                            ? 'Yükleniyor…'
                            : _qualityLabel(details.quality),
                        pathLabel: details == null
                            ? 'İndirme alanı'
                            : Platform.isIOS
                                ? 'Melodi içinde · özel çevrimdışı alan'
                                : details.path,
                        onQuality: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(
                              builder: (_) => const AudioQualityScreen(),
                            ))
                            .then((_) => _refreshSnapshot()),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: DownloadFilterBar(
                    value: _filter,
                    countFor: (filter) => _countFor(provider, filter),
                    onChanged: (value) {
                      setState(() {
                        _filter = value;
                        _selectedIds.clear();
                      });
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (visible.isEmpty)
                  DownloadEmptyState(filter: _filter)
                else
                  SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final task = visible[index];
                      return DownloadTaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        stateLabel: provider.stateText(task),
                        selected: _selectedIds.contains(task.id),
                        selectionMode: _selectionMode,
                        onTap: () async {
                          if (_selectionMode) {
                            _toggleSelected(task.id);
                            return;
                          }
                          await _playDownloaded(task);
                        },
                        onLongPress: () => _toggleSelected(task.id),
                        onCancel: () => provider.cancelTask(task.id),
                        onRetry: () => provider.retryTask(task.id),
                        onClearHistory: () =>
                            _showTaskMenu(context, provider, task),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      DownloadProvider provider, List<DownloadTask> visible) {
    if (_selectionMode) {
      final selectedTasks = provider.tasks
          .where((task) => _selectedIds.contains(task.id))
          .toList(growable: false);
      final hasActive = selectedTasks.any(_isActive);
      final hasFailed =
          selectedTasks.any((task) => task.state == DownloadState.failed);
      final hasTerminal = selectedTasks.any((task) =>
          task.state == DownloadState.completed ||
          task.state == DownloadState.failed);
      return AppBar(
        leading: IconButton(
          tooltip: 'Seçimi kapat',
          onPressed: () => setState(_selectedIds.clear),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text('${_selectedIds.length} seçildi'),
        actions: [
          IconButton(
            tooltip: 'Görünenlerin tümünü seç',
            onPressed: () => setState(() {
              if (visible.every((task) => _selectedIds.contains(task.id))) {
                _selectedIds.removeAll(visible.map((task) => task.id));
              } else {
                _selectedIds.addAll(visible.map((task) => task.id));
              }
            }),
            icon: const Icon(Icons.select_all_rounded),
          ),
          if (hasActive)
            IconButton(
              tooltip: 'Seçili indirmeleri iptal et',
              onPressed: () {
                provider.cancelTasks(_selectedIds);
                setState(_selectedIds.clear);
              },
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          if (hasFailed)
            IconButton(
              tooltip: 'Seçili sorunluları yeniden dene',
              onPressed: () {
                provider.retryTasks(_selectedIds);
                setState(_selectedIds.clear);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (hasTerminal)
            IconButton(
              tooltip: 'Seçilenleri geçmişten kaldır',
              onPressed: () {
                provider.clearTasks(_selectedIds);
                setState(_selectedIds.clear);
              },
              icon: const Icon(Icons.playlist_remove_rounded),
            ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        tooltip: 'Geri',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İndirmeler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Çevrimdışı müzik merkezi',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        if (provider.failedCount > 0)
          Badge.count(
            count: provider.failedCount,
            child: IconButton(
              tooltip: 'Tüm sorunluları yeniden dene',
              onPressed: provider.retryAllFailed,
              icon: const Icon(Icons.sync_problem_rounded),
            ),
          ),
        IconButton(
          tooltip: 'İndirme ayarları',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    );
  }

  List<DownloadTask> _visibleTasks(DownloadProvider provider) {
    final tasks = switch (_filter) {
      DownloadViewFilter.all => provider.tasks,
      DownloadViewFilter.active => provider.activeDownloads,
      DownloadViewFilter.completed => provider.completedDownloads,
      DownloadViewFilter.failed => provider.failedDownloads,
    };
    return List<DownloadTask>.from(tasks)
      ..sort((a, b) {
        final stateOrder = _stateOrder(a.state).compareTo(_stateOrder(b.state));
        if (stateOrder != 0) return stateOrder;
        return b.id.compareTo(a.id);
      });
  }

  int _countFor(DownloadProvider provider, DownloadViewFilter filter) {
    return switch (filter) {
      DownloadViewFilter.all => provider.totalCount,
      DownloadViewFilter.active => provider.activeCount,
      DownloadViewFilter.completed => provider.completedCount,
      DownloadViewFilter.failed => provider.failedCount,
    };
  }

  int _stateOrder(DownloadState state) => switch (state) {
        DownloadState.downloading => 0,
        DownloadState.pending => 1,
        DownloadState.failed => 2,
        DownloadState.completed => 3,
      };

  bool _isActive(DownloadTask task) =>
      task.state == DownloadState.pending ||
      task.state == DownloadState.downloading;

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _playDownloaded(DownloadTask task) async {
    if (task.state != DownloadState.completed) return;
    final path = task.filePath;
    final file = path == null ? null : File(path);
    if (file == null || !await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirilen dosya artık bulunamıyor')),
        );
      }
      return;
    }

    try {
      final stored = await DatabaseService.instance.getSongByPath(path!);
      final song = stored ??
          SongModel(
            id: 'download:${task.spotifyTrackId}',
            title: task.title,
            artist: task.artist,
            album: task.album ?? '',
            duration: Duration.zero,
            filePath: path,
            fileSize: await file.length(),
          );
      if (!mounted) return;
      await context.read<PlayerProvider>().playSong(song);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oynatma hatası: $error')),
        );
      }
    }
  }

  Future<void> _showTaskMenu(BuildContext context, DownloadProvider provider,
      DownloadTask task) async {
    final action = await showModalBottomSheet<_TaskMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.offline_pin_rounded),
              title: Text(task.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                Platform.isIOS
                    ? 'Melodi içinde · Dosyalar uygulamasında görünmez'
                    : task.filePath ?? 'İndirme kaydı',
              ),
            ),
            if (task.state == DownloadState.completed)
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Çal'),
                onTap: () => Navigator.pop(context, _TaskMenuAction.play),
              ),
            if (task.state == DownloadState.failed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Yeniden dene'),
                onTap: () => Navigator.pop(context, _TaskMenuAction.retry),
              ),
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded),
              title: const Text('Geçmişten kaldır'),
              subtitle: const Text('İndirilen müzik dosyası silinmez'),
              onTap: () => Navigator.pop(context, _TaskMenuAction.clear),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _TaskMenuAction.play:
        await _playDownloaded(task);
        break;
      case _TaskMenuAction.retry:
        provider.retryTask(task.id);
        break;
      case _TaskMenuAction.clear:
        provider.clearTasks([task.id]);
        break;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _qualityLabel(String quality) => switch (quality) {
        'normal' => 'Normal',
        'lossless' => 'Kayıpsız tercih',
        _ => 'Yüksek',
      };
}

class _DownloadSnapshot {
  const _DownloadSnapshot({
    required this.size,
    required this.path,
    required this.quality,
  });

  final int size;
  final String path;
  final String quality;
}

enum _TaskMenuAction { play, retry, clear }
