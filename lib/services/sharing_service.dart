import 'dart:async';

class SharedMediaFile {
  final String? path;
  final String? url;
  SharedMediaFile({this.path, this.url});
}

class SharingService {
  static SharingService? _instance;
  static SharingService get instance => _instance ??= SharingService._();
  SharingService._();

  final StreamController<SharedMediaFile> _onShareController = StreamController<SharedMediaFile>.broadcast();
  Stream<SharedMediaFile> get onShare => _onShareController.stream;

  void init() {}

  void handleSharedUrl(String url) {
    _onShareController.add(SharedMediaFile(url: url));
  }

  void dispose() {
    _onShareController.close();
  }
}
