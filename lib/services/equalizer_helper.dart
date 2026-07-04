import 'equalizer_helper_stub.dart'
    if (dart.library.android) 'equalizer_helper_android.dart';

import 'package:just_audio/just_audio.dart';

AndroidEqualizer? getAndroidEqualizer(AudioPlayer player) {
  return getAndroidEqualizerImpl(player);
}
