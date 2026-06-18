import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import 'database_service.dart';

class DiagnosticsService {
  static DiagnosticsService? _instance;

  DiagnosticsService._();

  static DiagnosticsService get instance {
    _instance ??= DiagnosticsService._();
    return _instance!;
  }

  Future<Map<String, dynamic>> generateDiagnosticBundle() async {
    final db = DatabaseService.instance;

    final version = AppConstants.appVersion;
    final buildNumber = AppConstants.buildNumber;

    final os = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;

    final dbVersion = (await db.rawQuery('PRAGMA user_version')).first['user_version'] as int? ?? 0;

    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'melodi.db'));
    int dbSize = 0;
    try {
      dbSize = await dbFile.length();
    } catch (_) {}

    final songCount = (await db.rawQuery('SELECT COUNT(*) as c FROM songs')).first['c'] as int? ?? 0;
    final playlistCount = (await db.rawQuery('SELECT COUNT(*) as c FROM playlists')).first['c'] as int? ?? 0;
    final settingsCount = (await db.rawQuery('SELECT COUNT(*) as c FROM settings')).first['c'] as int? ?? 0;
    final errorCount = (await db.rawQuery('SELECT COUNT(*) as c FROM error_logs')).first['c'] as int? ?? 0;

    final spotifyToken = await db.getSetting('spotify_access_token');
    final ytmusicCookie = await db.getSetting('ytmusic_cookie');
    final lastfmSession = await db.getSetting('lastfm_session_key');

    final errors = await db.getErrorLogs(10);

    final bundle = <String, dynamic>{
      'appVersion': version,
      'buildNumber': buildNumber,
      'platform': os,
      'platformVersion': osVersion,
      'databaseVersion': dbVersion,
      'databaseSizeBytes': dbSize,
      'tableCounts': {
        'songs': songCount,
        'playlists': playlistCount,
        'settings': settingsCount,
        'errorLogs': errorCount,
      },
      'services': {
        'spotifyConnected': spotifyToken != null && spotifyToken.isNotEmpty,
        'ytmusicConnected': ytmusicCookie != null && ytmusicCookie.isNotEmpty,
        'lastfmConnected': lastfmSession != null && lastfmSession.isNotEmpty,
      },
      'recentErrors': errors,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    await db.setSetting('diagnostics_bundle', jsonEncode(bundle));
    return bundle;
  }

  Future<void> logError(String context, String message, [StackTrace? stack]) async {
    try {
      final db = DatabaseService.instance;
      await db.insertErrorLog(context, message, stack?.toString());
    } catch (_) {
      debugPrint('Failed to log error: $_');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentErrors(int limit) async {
    final db = DatabaseService.instance;
    return db.getErrorLogs(limit);
  }

  Future<String> exportDiagnostics() async {
    final bundle = await generateDiagnosticBundle();
    final json = const JsonEncoder.withIndent('  ').convert(bundle);
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, 'melodi_diagnostics.json'));
    await file.writeAsString(json);
    return file.path;
  }

  Future<void> clearErrorLogs() async {
    final db = DatabaseService.instance;
    await db.clearErrorLogs();
  }
}
