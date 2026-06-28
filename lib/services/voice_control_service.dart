import 'package:flutter/services.dart';
import '../services/database_service.dart';

class VoiceControlService {
  static VoiceControlService? _instance;

  VoiceControlService._();

  static VoiceControlService get instance {
    _instance ??= VoiceControlService._();
    return _instance!;
  }

  static const _shortcutsKey = 'voice_shortcuts_enabled';

  Future<void> registerShortcuts() async {
    const channel = MethodChannel('com.melodi/voice_control');

    try {
      await channel.invokeMethod('registerShortcuts', {
        'intents': [
          'play_pause',
          'next_track',
          'previous_track',
          'shuffle_toggle',
          'repeat_toggle',
        ],
      });
    } on PlatformException catch (e) {
      _logError('registerShortcuts', e.message);
    }
  }

  Future<void> handleIntent(Map<String, dynamic> intent) async {
    final action = intent['action'] as String?;
    if (action == null) return;

    const channel = MethodChannel('com.melodi/voice_control');

    switch (action) {
      case 'play_pause':
        await channel.invokeMethod('playPause');
        break;
      case 'next_track':
        await channel.invokeMethod('nextTrack');
        break;
      case 'previous_track':
        await channel.invokeMethod('previousTrack');
        break;
      case 'shuffle_toggle':
        await channel.invokeMethod('shuffleToggle');
        break;
      case 'repeat_toggle':
        await channel.invokeMethod('repeatToggle');
        break;
    }

    await DatabaseService.instance.setSetting(
      'last_voice_command',
      action,
    );
  }

  Future<void> setShortcutsEnabled(bool enabled) async {
    await DatabaseService.instance.setSetting(
      _shortcutsKey,
      enabled ? '1' : '0',
    );
  }

  Future<bool> isShortcutsEnabled() async {
    final value = await DatabaseService.instance.getSetting(_shortcutsKey);
    return value == '1';
  }

  void _logError(String method, String? message) {}
}
