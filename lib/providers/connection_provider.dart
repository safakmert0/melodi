import 'package:flutter/foundation.dart';

/// Tracks connectivity/expiry of linked music accounts so the UI can surface a
/// reconnect banner. Spotify and YouTube Music account linking have been
/// removed; this provider now exists only as a lightweight, account-free stub
/// so existing wiring keeps compiling.
class ConnectionProvider extends ChangeNotifier {
  bool _dismissed = false;

  bool get shouldShowBanner => false;

  ConnectionProvider();

  Future<void> init() async {}

  Future<void> refreshStatus() async {}

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

}
