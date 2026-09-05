import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'music_scanner_service.dart';

/// Her açılışta seçili klasörü tarayıp yeni dosyaları kitaplığa ekleyen servis.
/// Ayarlar > İzlenecek Klasör ile yönetilir; onboarding sonrası da erişilebilir.
class WatchedFolderService {
  WatchedFolderService._();
  static final WatchedFolderService _instance = WatchedFolderService._();
  factory WatchedFolderService() => _instance;
  static WatchedFolderService get instance => _instance;

  static const String _watchedFolderKey = 'watched_folder';
  static const String _watchedFolderAutoScanKey = 'watched_folder_auto_scan';
  static const String _watchedFolderLastScanKey = 'watched_folder_last_scan';

  final DatabaseService _db = DatabaseService.instance;
  final MusicScannerService _scanner = MusicScannerService();
  final ValueNotifier<int> libraryRevision = ValueNotifier<int>(0);
  Timer? _watchTimer;
  bool _scanRunning = false;

  static const Duration scanInterval = Duration(seconds: 5);

  Future<String?> getWatchedFolder() async {
    try {
      final v = await _db.getSetting(_watchedFolderKey);
      if (v != null && v.trim().isNotEmpty) return v.trim();
      final multiple = await _db.getSetting('watched_folders');
      if (multiple != null && multiple.isNotEmpty) {
        final decoded = jsonDecode(multiple);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            if (item['enabled'] != false &&
                (item['path']?.toString().trim() ?? '').isNotEmpty) {
              return item['path'].toString().trim();
            }
          }
        }
      }
      final folders = await _enabledFolders();
      if (folders.isNotEmpty) return folders.first;
    } catch (_) {}
    return null;
  }

  Future<List<String>> getWatchedFolders() => _enabledFolders();

  Future<bool> isAutoScanEnabled() async {
    try {
      final v = await _db.getSetting(_watchedFolderAutoScanKey);
      // default true when folder is set
      if (v == null) return true;
      return v == 'true';
    } catch (_) {
      return true;
    }
  }

  Future<void> setAutoScanEnabled(bool enabled) async {
    try {
      await _db.setSetting(_watchedFolderAutoScanKey, enabled.toString());
    } catch (_) {}
    if (enabled) {
      await startMonitoring();
    } else {
      stopMonitoring();
    }
  }

  Future<void> setWatchedFolder(String path) async {
    try {
      final normalized = path.trim();
      final folders = await _enabledFolders();
      if (!folders.contains(normalized)) folders.add(normalized);
      await _db.setSetting(
        _watchedFolderKey,
        folders.isEmpty ? '' : folders.first,
      );
      await _db.setSetting(_watchedFolderLastScanKey, '');
      await _db.setSetting(
        'watched_folders',
        jsonEncode([
          for (final folder in folders) {'path': folder, 'enabled': true},
        ]),
      );
    } catch (e) {
      debugPrint('WatchedFolder set failed: $e');
    }
    await startMonitoring();
  }

  Future<void> removeWatchedFolder(String path) async {
    final normalized = path.trim();
    final folders = await _enabledFolders()
      ..removeWhere((folder) => folder == normalized);
    await _db.setSetting(
      _watchedFolderKey,
      folders.isEmpty ? '' : folders.first,
    );
    await _db.setSetting(
      'watched_folders',
      jsonEncode([
        for (final folder in folders) {'path': folder, 'enabled': true},
      ]),
    );
    await startMonitoring();
  }

  Future<void> clearWatchedFolder() async {
    try {
      await _db.setSetting(_watchedFolderKey, '');
      await _db.setSetting(_watchedFolderLastScanKey, '');
      await _db.setSetting('watched_folders', '[]');
    } catch (_) {}
    stopMonitoring();
  }

  /// Dosya seçiciyle klasör seçtir ve kaydet. iOS’ta getDirectoryPath desteklenmiyorsa
  /// çoklu dosya seçimi ile klasörü çıkar.
  Future<String?> pickAndSaveWatchedFolder() async {
    try {
      if (Platform.isIOS) {
        // iOS does not grant a normal app a permanent arbitrary-directory
        // path. Import selected files into our Documents container instead;
        // this directory remains visible in Files and can really be polled.
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const [
            'mp3',
            'm4a',
            'flac',
            'wav',
            'aac',
            'ogg',
            'wma',
            'alac',
            'aiff',
            'opus',
            'ape',
            'wv',
          ],
        );
        if (result == null || result.files.isEmpty) return null;
        final documents = await getApplicationDocumentsDirectory();
        final imports = Directory(p.join(documents.path, 'Melodi', 'Imports'));
        await imports.create(recursive: true);
        for (final picked in result.files) {
          final sourcePath = picked.path;
          if (sourcePath == null || !await File(sourcePath).exists()) continue;
          var destination = p.join(imports.path, p.basename(sourcePath));
          var suffix = 1;
          while (await File(destination).exists()) {
            destination = p.join(
              imports.path,
              '${p.basenameWithoutExtension(sourcePath)} ($suffix)${p.extension(sourcePath)}',
            );
            suffix++;
          }
          await File(sourcePath).copy(destination);
        }
        await setWatchedFolder(imports.path);
        await scanWatchedFolder();
        return imports.path;
      }
      String? dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'İzlenecek klasörü seç',
      );
      if (dir != null && dir.trim().isNotEmpty) {
        await setWatchedFolder(dir);
        return dir;
      }
    } catch (e) {
      debugPrint('pickAndSaveWatchedFolder error: $e');
    }
    return null;
  }

  /// Seçili klasörü tarar ve yeni şarkıları kitaplığa ekler.
  Future<int> scanWatchedFolder() async {
    if (_scanRunning) return 0;
    _scanRunning = true;
    try {
      final folders = await _enabledFolders();
      var added = 0;
      for (final folder in folders) {
        try {
          final newSongs = await _scanner.scanDirectoryAndSync(folder);
          added += newSongs.length;
        } catch (e) {
          debugPrint('WatchedFolder scan failed for $folder: $e');
        }
      }
      await _db.setSetting(
          _watchedFolderLastScanKey, DateTime.now().toIso8601String());
      if (added > 0) libraryRevision.value++;
      return added;
    } catch (e) {
      debugPrint('WatchedFolder scan failed: $e');
      return 0;
    } finally {
      _scanRunning = false;
    }
  }

  Future<List<String>> _enabledFolders() async {
    final result = <String>{};
    if (Platform.isIOS) {
      // Files > On My iPhone > Melodi is the app Documents container. Always
      // watch its user-facing Melodi directory, including Imports/Offline.
      final documents = await getApplicationDocumentsDirectory();
      final localMelodi = Directory(p.join(documents.path, 'Melodi'));
      await localMelodi.create(recursive: true);
      result.add(localMelodi.path);
    }
    final single = await _db.getSetting(_watchedFolderKey);
    if (single != null && single.trim().isNotEmpty) result.add(single.trim());
    final raw = await _db.getSetting('watched_folders');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final path = item['path']?.toString().trim() ?? '';
            if (item['enabled'] != false && path.isNotEmpty) result.add(path);
          }
        }
      } catch (_) {}
    }
    return result.toList();
  }

  Future<void> startMonitoring() async {
    stopMonitoring();
    if (!await isAutoScanEnabled() || (await _enabledFolders()).isEmpty) return;
    unawaited(scanWatchedFolder());
    _watchTimer = Timer.periodic(scanInterval, (_) {
      unawaited(scanWatchedFolder());
    });
  }

  void stopMonitoring() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// Uygulama açılışında çağrılır: auto-scan açıksa ve klasör varsa arka planda tara.
  Future<void> scanOnLaunchIfEnabled() async {
    try {
      final folders = await _enabledFolders();
      if (folders.isEmpty) return;
      final enabled = await isAutoScanEnabled();
      if (!enabled) return;
      await startMonitoring();
    } catch (e) {
      debugPrint('WatchedFolder launch scan error: $e');
    }
  }

  Future<DateTime?> getLastScanTime() async {
    try {
      final v = await _db.getSetting(_watchedFolderLastScanKey);
      if (v == null || v.isEmpty) return null;
      return DateTime.tryParse(v);
    } catch (_) {
      return null;
    }
  }
}
