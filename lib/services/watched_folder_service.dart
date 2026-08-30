import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
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

  Future<String?> getWatchedFolder() async {
    try {
      final v = await _db.getSetting(_watchedFolderKey);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {}
    return null;
  }

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
  }

  Future<void> setWatchedFolder(String path) async {
    try {
      await _db.setSetting(_watchedFolderKey, path.trim());
      await _db.setSetting(_watchedFolderLastScanKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('WatchedFolder set failed: $e');
    }
  }

  Future<void> clearWatchedFolder() async {
    try {
      await _db.setSetting(_watchedFolderKey, '');
      await _db.setSetting(_watchedFolderLastScanKey, '');
    } catch (_) {}
  }

  /// Dosya seçiciyle klasör seçtir ve kaydet. iOS’ta getDirectoryPath desteklenmiyorsa
  /// çoklu dosya seçimi ile klasörü çıkar.
  Future<String?> pickAndSaveWatchedFolder() async {
    try {
      String? dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'İzlenecek klasörü seç',
      );
      // iOS fallback: getDirectoryPath bazen null döner, dosyadan klasör çıkar
      if (dir == null && Platform.isIOS) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const [
            'mp3','m4a','flac','wav','aac','ogg','wma','alac','aiff','opus','ape','wv',
          ],
        );
        if (result != null && result.files.isNotEmpty) {
          final firstPath = result.files.first.path;
          if (firstPath != null) {
            dir = File(firstPath).parent.path;
          }
        }
      }
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
  /// Dönüş: eklenen yeni şarkı sayısı.
  Future<int> scanWatchedFolder() async {
    final folder = await getWatchedFolder();
    if (folder == null || folder.isEmpty) return 0;
    final dir = Directory(folder);
    if (!await dir.exists()) {
      debugPrint('WatchedFolder not exists: $folder');
      return 0;
    }
    try {
      final newSongs = await _scanner.scanDirectoryAndSync(folder);
      await _db.setSetting(_watchedFolderLastScanKey, DateTime.now().toIso8601String());
      debugPrint('WatchedFolder scan: +${newSongs.length} in $folder');
      return newSongs.length;
    } catch (e) {
      debugPrint('WatchedFolder scan failed: $e');
      return 0;
    }
  }

  /// Uygulama açılışında çağrılır: auto-scan açıksa ve klasör varsa arka planda tara.
  Future<void> scanOnLaunchIfEnabled() async {
    try {
      final folder = await getWatchedFolder();
      if (folder == null || folder.isEmpty) return;
      final enabled = await isAutoScanEnabled();
      if (!enabled) return;
      // Debounce: son taramadan 2dk geçmediyse atla (hızlı restart koruması)
      final lastStr = await _db.getSetting(_watchedFolderLastScanKey);
      if (lastStr != null && lastStr.isNotEmpty) {
        final last = DateTime.tryParse(lastStr);
        if (last != null && DateTime.now().difference(last).inMinutes < 2) {
          debugPrint('WatchedFolder: recent scan skipped');
          return;
        }
      }
      // Arka planda, UI bloklamadan
      unawaited(scanWatchedFolder());
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

void unawaited(Future<void> f) {}
