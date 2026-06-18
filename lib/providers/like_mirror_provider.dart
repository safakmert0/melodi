import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/like_mirror_service.dart';

class LikeMirrorProvider extends ChangeNotifier {
  final LikeMirrorService _service;
  bool _isMirroring = false;
  bool _enabled = false;
  DateTime? _lastMirroredAt;
  int _mirroredCount = 0;
  String? _error;
  Timer? _autoMirrorTimer;

  LikeMirrorProvider(this._service);

  LikeMirrorService get service => _service;
  bool get isMirroring => _isMirroring;
  bool get enabled => _enabled;
  DateTime? get lastMirroredAt => _lastMirroredAt;
  int get mirroredCount => _mirroredCount;
  String? get error => _error;

  Future<void> init() async {
    final db = DatabaseService.instance;
    final enabled = await db.getSetting('like_mirror_enabled');
    _enabled = enabled == 'true';

    final last = await db.getSetting('like_mirror_last_mirrored');
    if (last != null && last.isNotEmpty) {
      _lastMirroredAt = DateTime.tryParse(last);
    }

    _mirroredCount = await _service.getMirroredCount();
    notifyListeners();

    if (_enabled) {
      startAutoMirror();
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final db = DatabaseService.instance;
    await db.setSetting('like_mirror_enabled', value.toString());
    if (value) {
      startAutoMirror();
    } else {
      stopAutoMirror();
    }
    notifyListeners();
  }

  void startAutoMirror() {
    _autoMirrorTimer?.cancel();
    _autoMirrorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      mirrorNow();
    });
  }

  void stopAutoMirror() {
    _autoMirrorTimer?.cancel();
    _autoMirrorTimer = null;
  }

  Future<void> mirrorNow() async {
    if (_isMirroring) return;
    _isMirroring = true;
    _error = null;
    notifyListeners();

    try {
      await _service.checkAndMirror();
      _lastMirroredAt = DateTime.now();
      _mirroredCount = await _service.getMirroredCount();

      final db = DatabaseService.instance;
      await db.setSetting(
        'like_mirror_last_mirrored',
        _lastMirroredAt!.toIso8601String(),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('LikeMirror mirrorNow error: $e');
    } finally {
      _isMirroring = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoMirrorTimer?.cancel();
    super.dispose();
  }
}
