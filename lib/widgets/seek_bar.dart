import 'package:flutter/material.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../core/extensions/duration_ext.dart';

class MelodiSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onSeek;
  final Color activeColor;

  const MelodiSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    this.onSeek,
    this.activeColor = const Color(0xFF1DB954),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressBar(
          progress: position,
          total: duration,
          buffered: bufferedPosition,
          progressBarColor: activeColor,
          thumbColor: Colors.white,
          thumbRadius: 6,
          baseBarColor: const Color(0xFF404040),
          bufferedBarColor: const Color(0xFF535353),
          barHeight: 4,
          timeLabelTextStyle: const TextStyle(
            color: Color(0xFFB3B3B3),
            fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          onSeek: onSeek ?? (_) {},
        ),
      ],
    );
  }
}

class CompactSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double>? onChanged;
  final Color activeColor;

  const CompactSeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.onChanged,
    this.activeColor = const Color(0xFF1DB954),
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
        activeTrackColor: activeColor,
        inactiveTrackColor: const Color(0xFF404040),
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: onChanged,
      ),
    );
  }
}
