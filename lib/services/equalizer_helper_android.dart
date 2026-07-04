import 'package:just_audio/just_audio.dart';

AndroidEqualizer? getAndroidEqualizerImpl(AudioPlayer player) {
  try {
    return player.androidEqualizer;
  } catch (_) {
    return null;
  }
}
