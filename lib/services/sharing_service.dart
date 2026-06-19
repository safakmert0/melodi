import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharingService {
  static SharingService? _instance;
  static SharingService get instance => _instance ??= SharingService._();
  SharingService._();

  final StreamController<SharedMediaFile> _onShareController = StreamController<SharedMediaFile>.broadcast();
  Stream<SharedMediaFile> get onShare => _onShareController.stream;

  StreamSubscription<List<SharedMediaFile>>? _textSub;
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  void init() {
    _textSub = ReceiveSharingIntent.instance.getTextStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) _onShareController.add(files.first);
      },
      onError: (err) {},
    );

    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) _onShareController.add(files.first);
      },
      onError: (err) {},
    );

    ReceiveSharingIntent.instance.getInitialText().then(
      (List<SharedMediaFile>? files) {
        if (files != null && files.isNotEmpty) {
          _onShareController.add(files.first);
          ReceiveSharingIntent.instance.reset();
        }
      },
    );
  }

  void dispose() {
    _textSub?.cancel();
    _mediaSub?.cancel();
    _onShareController.close();
  }
}
