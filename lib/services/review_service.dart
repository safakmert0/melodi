import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'database_service.dart';

/// Anlamlı kullanımdan sonra mağaza yorumu ister.
/// Eşikler: 5, 25 ve 100 anlamlı oturum; istekler arası en az 30 gün.
class ReviewService {
  ReviewService._();
  static final ReviewService _instance = ReviewService._();
  factory ReviewService() => _instance;
  static ReviewService get instance => _instance;

  static const String _countKey = 'meaningful_session_count';
  static const String _lastPromptKey = 'last_review_prompt_at';
  static const List<int> _thresholds = [5, 25, 100];
  static const Duration _minSpacing = Duration(days: 30);

  final InAppReview _review = InAppReview.instance;
  final DatabaseService _db = DatabaseService.instance;

  Future<void> bump() async {
    try {
      final raw = await _db.getSetting(_countKey);
      final count = (int.tryParse(raw ?? '') ?? 0) + 1;
      await _db.setSetting(_countKey, count.toString());
      if (_thresholds.contains(count)) {
        await maybePrompt(forceCount: count);
      }
    } catch (e) {
      debugPrint('Review bump failed: $e');
    }
  }

  Future<void> maybePrompt({int? forceCount}) async {
    try {
      if (!Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid) return;
      if (!await _review.isAvailable()) return;
      final lastRaw = await _db.getSetting(_lastPromptKey);
      if (lastRaw != null && lastRaw.isNotEmpty) {
        final last = DateTime.tryParse(lastRaw);
        if (last != null &&
            DateTime.now().difference(last) < _minSpacing) {
          return;
        }
      }
      if (forceCount == null) {
        final raw = await _db.getSetting(_countKey);
        final count = int.tryParse(raw ?? '') ?? 0;
        if (!_thresholds.contains(count)) return;
      }
      await _db.setSetting(
          _lastPromptKey, DateTime.now().toIso8601String());
      await _review.requestReview();
    } catch (e) {
      debugPrint('Review prompt failed: $e');
    }
  }
}
