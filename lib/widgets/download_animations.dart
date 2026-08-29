import 'package:flutter/material.dart';

class AnimatedDownloadRing extends StatelessWidget {
  final double progress;
  final bool isComplete;
  const AnimatedDownloadRing({super.key, required this.progress, this.isComplete = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(value: isComplete ? 1 : progress.clamp(0, 1), strokeWidth: 2.5, color: scheme.onSurfaceVariant, backgroundColor: scheme.surfaceContainerHighest)),
          if (isComplete) Icon(Icons.check_rounded, size: 14, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class WaveProgressBar extends StatelessWidget {
  final double progress;
  const WaveProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 4,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0, 1),
        alignment: Alignment.centerLeft,
        child: Container(decoration: BoxDecoration(color: scheme.onSurfaceVariant, borderRadius: BorderRadius.circular(4))),
      ),
    );
  }
}

class PulseStorageMeter extends StatelessWidget {
  final double used;
  final double total;
  const PulseStorageMeter({super.key, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Container(
      height: 6,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        widthFactor: ratio,
        alignment: Alignment.centerLeft,
        child: Container(decoration: BoxDecoration(color: scheme.onSurfaceVariant, borderRadius: BorderRadius.circular(4))),
      ),
    );
  }
}
