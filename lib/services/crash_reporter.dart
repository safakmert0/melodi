import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'diagnostics_service.dart';

class CrashReporter {
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = (FlutterErrorDetails details) {
      DiagnosticsService.instance.logError(
        'flutter_error',
        details.exceptionAsString(),
        details.stack,
      );
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      DiagnosticsService.instance.logError(
        'platform_error',
        error.toString(),
        stack,
      );
      if (kDebugMode) {
        debugPrint('Platform error: $error\n$stack');
      }
      return true;
    };
  }
}
