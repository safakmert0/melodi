import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> show({required int id, required String title, required String body, String? payload}) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      'melodi_channel',
      'Melodi',
      channelDescription: 'Melodi bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> showDownloadComplete(String trackName) async {
    await show(id: 1001, title: 'İndirme Tamamlandı', body: '$trackName indirildi');
  }

  Future<void> showDownloadFailed(String trackName) async {
    await show(id: 1002, title: 'İndirme Başarısız', body: '$trackName indirilemedi');
  }

  Future<void> showBatchComplete(int count) async {
    await show(id: 1003, title: 'Toplu İndirme Tamamlandı', body: '$count şarkı indirildi');
  }

  Future<void> cancel({required int id}) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
