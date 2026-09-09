import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS security-scoped bookmark hattı (native: WatchedFolderHandler).
///
/// iOS kum havuzu, uygulama kutusu dışındaki klasörlere kalıcı erişim vermez.
/// Bu kanal üzerinden seçilen klasörün bookmark'ı saklanır; her taramada
/// çözülüp erişim yeniden alınır. Böylece dış klasörler kopyalanmadan
/// yerinde izlenir. Kanal yoksa (eski derleme / diğer platformlar)
/// MissingPluginException düşer, çağıran eski akışa geri döner.
class WatchedFolderBookmarks {
  WatchedFolderBookmarks._();

  static const MethodChannel _channel =
      MethodChannel('com.melodi/watched_folders');

  /// Klasör seçtirir. Dönüş: (yol, iCloud reddi mi?).
  /// Yol null ise kullanıcı vazgeçmiştir ya da hata olmuştur.
  /// Kanal yoksa MissingPluginException fırlatır.
  static Future<({String? path, bool icloudRejected})> pickFolder() async {
    try {
      final result = await _channel.invokeMethod<dynamic>('pickFolder');
      if (result == null) return (path: null, icloudRejected: false);
      if (result is Map) {
        final path = result['path']?.toString().trim() ?? '';
        return (path: path.isEmpty ? null : path, icloudRejected: false);
      }
      final path = result.toString().trim();
      return (path: path.isEmpty ? null : path, icloudRejected: false);
    } on MissingPluginException {
      rethrow;
    } on PlatformException catch (e) {
      // Proje kararı: yalnızca yerel klasörler; iCloud reddini üstte göster.
      if (e.code == 'icloud_not_supported') {
        return (path: null, icloudRejected: true);
      }
      debugPrint('WatchedFolderBookmarks.pickFolder failed: $e');
      return (path: null, icloudRejected: false);
    } catch (e) {
      debugPrint('WatchedFolderBookmarks.pickFolder failed: $e');
      return (path: null, icloudRejected: false);
    }
  }

  /// Kaydedilmiş bookmark'ları çözer, erişimi tazeler.
  /// Dönüş: şu an erişilebilir klasör yolları.
  static Future<List<String>> resolveFolders() async {
    try {
      final result = await _channel.invokeMethod<dynamic>('resolveFolders');
      if (result is! Map) return const [];
      final folders = result['folders'];
      if (folders is! List) return const [];
      final paths = <String>[];
      for (final entry in folders) {
        final path = entry is Map
            ? entry['path']?.toString().trim() ?? ''
            : entry.toString().trim();
        if (path.isNotEmpty && !paths.contains(path)) paths.add(path);
      }
      return paths;
    } on MissingPluginException {
      rethrow;
    } catch (e) {
      debugPrint('WatchedFolderBookmarks.resolveFolders failed: $e');
      return const [];
    }
  }

  static Future<void> removeFolder(String path) async {
    try {
      await _channel.invokeMethod<bool>('removeFolder', {'path': path});
    } catch (e) {
      debugPrint('WatchedFolderBookmarks.removeFolder failed: $e');
    }
  }

  static Future<void> clearFolders() async {
    try {
      await _channel.invokeMethod<bool>('clearFolders');
    } catch (e) {
      debugPrint('WatchedFolderBookmarks.clearFolders failed: $e');
    }
  }
}
