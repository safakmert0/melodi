import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'melodi_channel',
      'Melodi',
      channelDescription: 'Melodi notifications',
      importance: Importance.low,
      priority: Priority.low,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> showDownloadComplete(String trackName) async {
    await show(
      id: 100,
      title: 'Download Complete',
      body: trackName,
    );
  }

  Future<void> showDownloadFailed(String trackName) async {
    await show(
      id: 101,
      title: 'Download Failed',
      body: trackName,
    );
  }

  Future<void> showBatchComplete(int count) async {
    await show(
      id: 102,
      title: 'Downloads Complete',
      body: '$count tracks downloaded',
    );
  }

  Future<void> cancel(int? id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
