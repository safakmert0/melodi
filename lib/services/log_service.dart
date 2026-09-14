import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Uygulama icinde loglari toplar, bellekte tutar, dosyaya yazar
/// (Files app'te Documents/Melodi/logs.txt olarak gorunur).
class LogService extends ChangeNotifier {
  LogService._();
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  static LogService get instance => _instance;

  static const int _maxMemoryEntries = 2000;
  static const Duration _flushInterval = Duration(seconds: 5);

  final List<LogEntry> _buffer = [];
  final StreamController<List<LogEntry>> _controller =
      StreamController<List<LogEntry>>.broadcast();
  Timer? _flushTimer;
  File? _logFile;
  bool _initialized = false;

  Stream<List<LogEntry>> get logStream => _controller.stream;
  List<LogEntry> get currentLogs => List.unmodifiable(_buffer);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final melodiDir = Directory(p.join(docs.path, 'Melodi'));
      if (!await melodiDir.exists()) await melodiDir.create(recursive: true);
      _logFile = File(p.join(melodiDir.path, 'logs.txt'));
      if (!await _logFile!.exists()) await _logFile!.create();
      _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
      _initialized = true;
      log('LogService initialized', level: LogLevel.info, tag: 'LogService');
    } catch (e) {
      debugPrint('LogService init failed: $e');
    }
  }

  void log(String message,
      {LogLevel level = LogLevel.info, String tag = '', Object? error, StackTrace? stack}) {
    if (!_initialized) init();
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
      stack: stack?.toString(),
    );
    _buffer.add(entry);
    if (_buffer.length > _maxMemoryEntries) {
      _buffer.removeRange(0, _buffer.length - _maxMemoryEntries);
    }
    _controller.add(List.unmodifiable(_buffer));
    // Ayrica standart cikisa da yaz (Xcode/console icin)
    final prefix = _levelPrefix(level);
    final tagStr = tag.isNotEmpty ? '[$tag] ' : '';
    debugPrint('$prefix $tagStr$message');
    if (error != null) debugPrint('  Error: $error');
    if (stack != null) debugPrint('  Stack: $stack');
  }

  void d(String message, {String tag = ''}) => log(message, level: LogLevel.debug, tag: tag);
  void i(String message, {String tag = ''}) => log(message, level: LogLevel.info, tag: tag);
  void w(String message, {String tag = '', Object? error}) => log(message, level: LogLevel.warning, tag: tag, error: error);
  void e(String message, {String tag = '', Object? error, StackTrace? stack}) => log(message, level: LogLevel.error, tag: tag, error: error, stack: stack);

  void _flush() {
    if (_logFile == null) return;
    try {
      final sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
      for (final entry in _buffer) {
        sink.writeln(entry.toFileString());
      }
      sink.close();
    } catch (_) {}
  }

  Future<String?> getLogFilePath() async {
    if (_logFile == null) await init();
    return _logFile?.path;
  }

  Future<String> exportLogs() async {
    if (_logFile == null) await init();
    return _logFile?.path ?? '';
  }

  void clear() {
    _buffer.clear();
    _controller.add([]);
    if (_logFile != null) {
      try { _logFile!.writeAsStringSync(''); } catch (_) {}
    }
    notifyListeners();
  }

  void dispose() {
    _flushTimer?.cancel();
    _flush();
    _controller.close();
  }

  String _levelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return '🔍';
      case LogLevel.info: return 'ℹ️';
      case LogLevel.warning: return '⚠️';
      case LogLevel.error: return '❌';
    }
  }
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stack,
  });
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? error;
  final String? stack;

  String get levelLabel {
    switch (level) {
      case LogLevel.debug: return 'DEBUG';
      case LogLevel.info: return 'INFO';
      case LogLevel.warning: return 'WARN';
      case LogLevel.error: return 'ERROR';
    }
  }

  String get levelEmoji {
    switch (level) {
      case LogLevel.debug: return '🔍';
      case LogLevel.info: return 'ℹ️';
      case LogLevel.warning: return '⚠️';
      case LogLevel.error: return '❌';
    }
  }

  String toFileString() {
    final ts = timestamp.toIso8601String();
    final tagStr = tag.isNotEmpty ? '[$tag] ' : '';
    var line = '[$ts] ${levelEmoji} $levelLabel $tagStr$message';
    if (error != null) line += '\n  Error: $error';
    if (stack != null) line += '\n  Stack: $stack';
    return line;
  }

  String toUiString() {
    final ts = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
    final tagStr = tag.isNotEmpty ? '[$tag] ' : '';
    return '[$ts] $levelEmoji $tagStr$message';
  }
}

/// Kullanım kolayligi icin global kısayol.
LogService get L => LogService.instance;