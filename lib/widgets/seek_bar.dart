import 'package:flutter/material.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class MelodiSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onSeek;
  final Color? activeColor;

  const MelodiSeekBar({super.key, required this.position, required this.duration, required this.bufferedPosition, this.onSeek, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeDuration = duration.inMilliseconds > 0 ? duration : Duration.zero;
    final safePosition = safeDuration.inMilliseconds > 0
        ? Duration(milliseconds: position.inMilliseconds.clamp(0, safeDuration.inMilliseconds))
        : Duration.zero;
    final safeBuffered = safeDuration.inMilliseconds > 0
        ? Duration(milliseconds: bufferedPosition.inMilliseconds.clamp(0, safeDuration.inMilliseconds))
        : bufferedPosition;

    return ProgressBar(
      progress: safePosition,
      total: safeDuration,
      buffered: safeBuffered,
      progressBarColor: activeColor ?? scheme.onSurface,
      thumbColor: scheme.onSurface,
      thumbRadius: 6,
      baseBarColor: scheme.surfaceContainerHighest,
      bufferedBarColor: scheme.outlineVariant.withValues(alpha: 0.5),
      barHeight: 3,
      timeLabelTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
      onSeek: (pos) {
        if (onSeek != null && safeDuration.inMilliseconds > 0) {
          final clampedPos = Duration(milliseconds: pos.inMilliseconds.clamp(0, safeDuration.inMilliseconds));
          onSeek!(clampedPos);
        }
      },
    );
  }
}

class CompactSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double>? onChanged;
  final Color? activeColor;
  const CompactSeekBar({super.key, required this.position, required this.duration, this.onChanged, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 0), activeTrackColor: activeColor ?? scheme.onSurface, inactiveTrackColor: scheme.surfaceContainerHighest),
      child: Slider(value: progress.clamp(0.0, 1.0), onChanged: onChanged),
    );
  }
}
