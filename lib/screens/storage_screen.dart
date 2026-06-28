import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../core/localization.dart';
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

  int _totalSize = 0;
  Map<String, int> _usage = {'audio': 0, 'art': 0, 'other': 0};
  int _fileCount = 0;
  Map<String, Map<String, int>> _formatBreakdown = {};
  String _location = '';
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
      _storage.getLibrarySize(),
      _storage.getStorageUsage(),
      _storage.getFileCount(),
      _storage.getFormatBreakdown(),
      _storage.getStorageLocation(),
    ]);
    if (!mounted) return;
    setState(() {
      _totalSize = results[0] as int;
      _usage = results[1] as Map<String, int>;
      _fileCount = results[2] as int;
      _formatBreakdown = results[3] as Map<String, Map<String, int>>;
      _location = results[4] as String;
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          AppLocale.tr('storage'),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _refresh,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUsageCard(
                      used, totalAudio, totalArt, totalOther),
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
                    _location,
                    Icons.folder_rounded,
                    Colors.orange,
                  ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.tr('library_size'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatBytes(used),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (totalAudio > 0)
                    Expanded(
                      flex: totalAudio,
                      child: Container(color: AppTheme.primaryColor),
                    ),
                  if (totalArt > 0)
                    Expanded(
                      flex: totalArt,
                      child: Container(color: Colors.amber),
                    ),
                  if (totalOther > 0)
                    Expanded(
                      flex: totalOther,
                      child: Container(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _usageLegend(AppTheme.primaryColor, AppLocale.tr('audio'),
              _formatBytes(totalAudio)),
          const SizedBox(height: 4),
          _usageLegend(Colors.amber, AppLocale.tr('artists'),
              _formatBytes(totalArt)),
          const SizedBox(height: 4),
          _usageLegend(Colors.grey, 'Other',
              _formatBytes(totalOther)),
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
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          size,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.tr('format_breakdown'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
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
                    width: 48,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ext,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count ${AppLocale.tr('songs')}',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatBytes(size),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isMoving ? null : _clearCache,
            icon: Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text(AppLocale.tr('clear_cache')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                      color: Colors.black,
                    ),
                  )
                : Icon(Icons.drive_folder_upload_rounded, size: 18),
            label: Text(_isMoving
                ? AppLocale.tr('move_library')
                : AppLocale.tr('move_library')),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
            onPressed: _backupDatabase,
            icon: Icon(Icons.backup_rounded, size: 18),
            label: Text('Veritabanı Yedekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          AppLocale.tr('clear_cache'),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '${AppLocale.tr('clear_cache')}?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocale.tr('cancel'),
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocale.tr('clear_cache'),
              style: TextStyle(color: AppTheme.errorColor),
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
          backgroundColor: AppTheme.primaryColor,
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
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocale.tr('move_library')}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    if (mounted) setState(() => _isMoving = false);
  }

  Future<void> _backupDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Veritabanı Yedekle', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Veritabanı yedeklenecek. Devam edilsin mi?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocale.tr('cancel'), style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yedekle', style: TextStyle(color: AppTheme.primaryColor)),
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
          content: Text(path != null ? 'Yedek oluşturuldu: $path' : 'Yedekleme başarısız'),
          backgroundColor: path != null ? AppTheme.primaryColor : AppTheme.errorColor,
        ),
      );
    }
  }
}
