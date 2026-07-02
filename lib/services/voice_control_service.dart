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
    // Voice Shortcuts / SiriKit integration requires Apple entitlements.
    // Placeholder for future implementation.
  }

  Future<void> handleIntent(Map<String, dynamic> intent) async {
    final action = intent['action'] as String?;
    if (action == null) return;
    await DatabaseService.instance.setSetting('last_voice_command', action);
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
}
