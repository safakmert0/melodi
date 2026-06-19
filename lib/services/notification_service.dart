class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  Future<void> init() async {}

  Future<void> show({required int id, required String title, required String body, String? payload}) async {}

  Future<void> showDownloadComplete(String trackName) async {}
  Future<void> showDownloadFailed(String trackName) async {}
  Future<void> showBatchComplete(int count) async {}
  Future<void> cancel({required int id}) async {}
  Future<void> cancelAll() async {}
}
