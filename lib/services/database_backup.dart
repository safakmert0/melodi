import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class DatabaseBackup {
  static final DatabaseBackup _instance = DatabaseBackup._();
  factory DatabaseBackup() => _instance;
  DatabaseBackup._();

  Future<String?> createBackup() async {
    try {
      final db = await DatabaseService.instance.database;
      final dbPath = db.path;
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      await DatabaseService.instance.resetDatabase();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupPath = '${backupDir.path}/melodi_backup_$timestamp.db';
      await File(dbPath).copy(backupPath);
      return backupPath;
    } catch (e) {
      debugPrint('Backup failed: $e');
      return null;
    }
  }

  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final db = await DatabaseService.instance.database;
      final dbPath = db.path;
      await DatabaseService.instance.resetDatabase();
      await File(backupPath).copy(dbPath);
      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) return [];
      final files = await backupDir.list().toList();
      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        if (file is File && file.path.endsWith('.db')) {
          final stat = await file.stat();
          backups.add({
            'path': file.path,
            'name': file.path.split('/').last,
            'size': stat.size,
            'modified': stat.modified,
          });
        }
      }
      backups.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
      return backups;
    } catch (e) {
      debugPrint('Get backups failed: $e');
      return [];
    }
  }

  Future<bool> deleteBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete backup failed: $e');
      return false;
    }
  }

  Future<int> getBackupCount() async {
    final backups = await getBackups();
    return backups.length;
  }

  Future<int> getTotalBackupSize() async {
    final backups = await getBackups();
    int total = 0;
    for (final b in backups) {
      total += (b['size'] as int?) ?? 0;
    }
    return total;
  }
}
