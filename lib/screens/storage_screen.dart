import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../models/song_model.dart';
import '../services/storage_manager.dart';
import '../services/database_service.dart';
import '../services/database_backup.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final StorageManager _storage = StorageManager.instance;

  Map<String, int> _usage = {'audio': 0, 'art': 0, 'other': 0};
  int _fileCount = 0;
  Map<String, Map<String, int>> _formatBreakdown = {};
  String _location = '';
  List<SongModel> _downloadedSongs = [];
  bool _isLoading = true;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _storage.getStorageUsage(),
      _storage.getFileCount(),
      _storage.getFormatBreakdown(),
      _storage.getStorageLocation(),
      DatabaseService.instance.getDownloadedSongs(),
    ]);
    if (!mounted) return;
    setState(() {
      _usage = results[0] as Map<String, int>;
      _fileCount = results[1] as int;
      _formatBreakdown = results[2] as Map<String, Map<String, int>>;
      _location = results[3] as String;
      _downloadedSongs = results[4] as List<SongModel>;
      _isLoading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    int totalAudio = _usage['audio'] ?? 0;
    int totalArt = _usage['art'] ?? 0;
    int totalOther = _usage['other'] ?? 0;
    int used = totalAudio + totalArt + totalOther;

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          AppLocale.tr('storage'),
          style: TextStyle(color: colors.onSurface, fontSize: 16),
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: colors.onSurfaceVariant, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _refresh,
              color: colors.onSurfaceVariant,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUsageCard(used, totalAudio, totalArt, totalOther),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    AppLocale.tr('file_label'),
                    '$_fileCount',
                    Icons.insert_drive_file_rounded,
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    AppLocale.tr('storage_location'),
                    Platform.isIOS
                        ? 'Melodi · Özel çevrimdışı alan'
                        : _location,
                    Icons.folder_rounded,
                    Colors.orange,
                  ),
                  const SizedBox(height: 20),
                  _buildDownloadedSongs(),
                  const SizedBox(height: 20),
                  _buildFormatBreakdown(),
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildUsageCard(
      int used, int totalAudio, int totalArt, int totalOther) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.tr('library_size'),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatBytes(used),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (totalAudio > 0)
                    Expanded(
                      flex: totalAudio,
                      child: Container(color: colors.onSurface),
                    ),
                  if (totalArt > 0)
                    Expanded(
                      flex: totalArt,
                      child: Container(color: colors.onSurfaceVariant),
                    ),
                  if (totalOther > 0)
                    Expanded(
                      flex: totalOther,
                      child: Container(color: colors.outlineVariant),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _usageLegend(colors.onSurface, AppLocale.tr('audio'),
              _formatBytes(totalAudio)),
          const SizedBox(height: 4),
          _usageLegend(
              colors.onSurfaceVariant, AppLocale.tr('artists'), _formatBytes(totalArt)),
          const SizedBox(height: 4),
          _usageLegend(colors.outline, 'Other', _formatBytes(totalOther)),
        ],
      ),
    );
  }

  Widget _usageLegend(Color color, String label, String size) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
        ),
        const Spacer(),
        Text(
          size,
          style: TextStyle(
            color: MelodiTheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      String label, String value, IconData icon, Color iconColor) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Icon(icon, color: colors.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: colors.onSurfaceVariant, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBreakdown() {
    if (_formatBreakdown.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.tr('format_breakdown'),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._formatBreakdown.entries.map((entry) {
            final ext = entry.key.toUpperCase();
            final count = entry.value['count'] ?? 0;
            final size = entry.value['size'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Text(
                      ext,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count ${AppLocale.tr('songs')}',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatBytes(size),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDownloadedSongs() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded,
                  color: colors.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocale.tr('downloads_subtitle'),
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_downloadedSongs.length}',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_downloadedSongs.isEmpty)
            Text(
              AppLocale.tr('no_downloads'),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          else
            SizedBox(
              height: (_downloadedSongs.length * 56.0).clamp(0.0, 320.0),
              child: ListView.separated(
                physics: const ClampingScrollPhysics(),
                itemCount: _downloadedSongs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final song = _downloadedSongs[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.music_note_rounded,
                        size: 18, color: colors.onSurfaceVariant),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isMoving ? null : _clearCache,
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text(AppLocale.tr('clear_cache')),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (!Platform.isIOS) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isMoving ? null : _moveLibrary,
              icon: _isMoving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.drive_folder_upload_rounded, size: 18),
              label: Text(AppLocale.tr('move_library')),
              style: FilledButton.styleFrom(
                backgroundColor: colors.onSurface,
                foregroundColor: colors.surface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _backupDatabase,
            icon: const Icon(Icons.backup_rounded, size: 18),
            label: const Text('Veritabanı Yedekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearCache() async {
    final colors = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        title: Text(
          AppLocale.tr('clear_cache'),
          style: TextStyle(color: colors.onSurface, fontSize: 16),
        ),
        content: Text(
          '${AppLocale.tr('clear_cache')}?',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocale.tr('cancel'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocale.tr('clear_cache'),
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _storage.clearCache();
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.tr('clear_cache')),
        ),
      );
    }
  }

  Future<void> _moveLibrary() async {
    final newPath = await FilePicker.platform.getDirectoryPath();
    if (newPath == null || newPath.isEmpty) return;
    setState(() => _isMoving = true);
    try {
      await _storage.moveLibrary(newPath, onProgress: (progress) {
        if (mounted) setState(() {});
      });
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('move_library')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocale.tr('move_library')}: $e'),
          ),
        );
      }
    }
    if (mounted) setState(() => _isMoving = false);
  }

  Future<void> _backupDatabase() async {
    final colors = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        title: Text('Veritabanı Yedekle',
            style: TextStyle(color: colors.onSurface, fontSize: 16)),
        content: Text('Veritabanı yedeklenecek. Devam edilsin mi?',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: colors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yedekle',
                style: TextStyle(color: colors.onSurface)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final backup = DatabaseBackup();
    final path = await backup.createBackup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null
              ? 'Yedek oluşturuldu: $path'
              : 'Yedekleme başarısız'),
        ),
      );
    }
  }
}
