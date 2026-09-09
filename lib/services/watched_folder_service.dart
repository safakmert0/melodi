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

  /// Uygulamanin kendi klasoru (Documents/Melodi). Her zaman izlenir,
  /// silinemez; indirmeler ve kopyasiz izleme buradan kapsanir.
  Future<String> systemFolderPath() async {
    final documents = await getApplicationDocumentsDirectory();
    final localMelodi = Directory(p.join(documents.path, 'Melodi'));
    await localMelodi.create(recursive: true);
    return localMelodi.path;
  }

  Future<String?> getWatchedFolder() async {
    try {
      final folders = await _userFolders();
      if (folders.isNotEmpty) return folders.first;
    } catch (_) {}
    return null;
  }

  /// Ayarlar UI listesi: SADECE kullanicinin ekledikleri (silinebilir).
  /// Eskiden sistem klasoru de listeye kariyordu; silme/temizleme bu yuzden
  /// ise yaramiyor gorunuyordu.
  Future<List<String>> getWatchedFolders() => _userFolders();

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
      final folders = await _userFolders();
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
    final folders = await _userFolders()
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
    // Klasor artik izlenmiyor: altindaki kayitlari kutuphaneden dusur
    // (dosyalara dokunulmaz). Sistem klasoru alti korunur.
    await _removeLibraryEntriesUnder(normalized);
    libraryRevision.value++;
    await startMonitoring();
  }

  Future<void> clearWatchedFolder() async {
    try {
      final removed = await _userFolders();
      await _db.setSetting(_watchedFolderKey, '');
      await _db.setSetting(_watchedFolderLastScanKey, '');
      await _db.setSetting('watched_folders', '[]');
      for (final folder in removed) {
        await _removeLibraryEntriesUnder(folder);
      }
      libraryRevision.value++;
    } catch (_) {}
    // Sistem klasoru izlenmeye devam eder; izlemeyi tamamen durdurma.
    await startMonitoring();
  }

  /// Verilen klasor altindaki sarki kayitlarini DB'den siler.
  /// Dosyalar silinmez. Sistem (uygulama) klasoru alti korunur cunku
  /// sistem taramasi kapsar; silinseler bile geri gelirler.
  Future<void> _removeLibraryEntriesUnder(String folder) async {
    try {
      final normFolder = p.normalize(folder);
      if (Platform.isIOS) {
        final system = p.normalize(await systemFolderPath());
        if (_isWithin(normFolder, system)) return;
      }
      final songs = await _db.getAllSongs();
      for (final song in songs) {
        try {
          if (_isWithin(p.normalize(song.filePath), normFolder)) {
            await _db.deleteSong(song.id);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('WatchedFolder cleanup failed: $e');
    }
  }

  bool _isWithin(String path, String dir) {
    if (path == dir) return true;
    final sep = Platform.pathSeparator;
    final prefix = dir.endsWith(sep) ? dir : '$dir$sep';
    return path.startsWith(prefix);
  }

  /// Dosya seçiciyle klasör seçtir ve kaydet. iOS’ta getDirectoryPath desteklenmiyorsa
  /// çoklu dosya seçimi ile klasörü çıkar.
  ///
  /// Kopyasiz izleme: secilen dosya zaten uygulama Documents'i altindaysa
  /// kopyalanmaz, yerinde izlenir (sistem taramasi kapsar). Disaridaysa
  /// (iCloud, baska uygulama) kalici erisim icin gelen kutusuna kopyalanir.
  /// Donus: kopya yapildiysa gelen kutusu yolu, hepsi yerindeyse sistem
  /// klasoru yolu, iptal/bos ise null.
  Future<String?> pickAndSaveWatchedFolder() async {
    try {
      if (Platform.isIOS) {
        // iOS does not grant a normal app a permanent arbitrary-directory
        // path. Files outside our Documents container are imported into it;
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
        final docsNorm = p.normalize(documents.path);
        final inbox = Directory(
            p.join(documents.path, 'Melodi', 'Offline', 'Imported Files'));
        await inbox.create(recursive: true);
        var copied = 0;
        var inPlace = 0;
        for (final picked in result.files) {
          final sourcePath = picked.path;
          if (sourcePath == null || !await File(sourcePath).exists()) continue;
          if (_isWithin(p.normalize(sourcePath), docsNorm)) {
            // Zaten uygulama klasorunde: kopyalama, yerinde izle.
            inPlace++;
            continue;
          }
          var destination = p.join(inbox.path, p.basename(sourcePath));
          var suffix = 1;
          while (await File(destination).exists()) {
            destination = p.join(
              inbox.path,
              '${p.basenameWithoutExtension(sourcePath)} ($suffix)${p.extension(sourcePath)}',
            );
            suffix++;
          }
          await File(sourcePath).copy(destination);
          copied++;
        }
        await scanWatchedFolder();
        if (copied > 0) {
          await setWatchedFolder(inbox.path);
          return inbox.path;
        }
        if (inPlace > 0) return systemFolderPath();
        return null;
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

  /// Kullanicinin ekledigi klasorler (DB). Sistem klasoru dahil DEGIL.
  Future<List<String>> _userFolders() async {
    final result = <String>{};
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

  Future<List<String>> _enabledFolders() async {
    final result = <String>{};
    if (Platform.isIOS) {
      // Files > On My iPhone > Melodi is the app Documents container. Always
      // watch its user-facing Melodi directory, including Imports/Offline.
      // Bu sistem klasorudur: taramaya dahildir ama kullanici listesinde
      // gosterilmez ve silinemez.
      try {
        result.add(await systemFolderPath());
      } catch (_) {}
    }
    result.addAll(await _userFolders());
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
