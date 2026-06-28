import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class AnimatedDownloadRing extends StatefulWidget {
  final double progress;
  final bool isComplete;

  const AnimatedDownloadRing({
    super.key,
    required this.progress,
    this.isComplete = false,
  });

  @override
  State<AnimatedDownloadRing> createState() => _AnimatedDownloadRingState();
}

class _AnimatedDownloadRingState extends State<AnimatedDownloadRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * pi,
          child: CustomPaint(
            size: const Size(32, 32),
            painter: _RingPainter(
              progress: widget.progress,
              isComplete: widget.isComplete,
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isComplete;

  _RingPainter({required this.progress, required this.isComplete});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = MelodiTheme.surfaceBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = MelodiTheme.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    if (isComplete) {
      final checkPaint = Paint()
        ..color = MelodiTheme.primaryGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(center.dx - 6, center.dy)
        ..lineTo(center.dx - 2, center.dy + 5)
        ..lineTo(center.dx + 7, center.dy - 5);

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isComplete != isComplete;
  }
}

class WaveProgressBar extends StatefulWidget {
  final double progress;

  const WaveProgressBar({super.key, required this.progress});

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: MelodiTheme.surfaceBright,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            widthFactor: widget.progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MelodiTheme.primaryGreen,
                    MelodiTheme.primaryGreenBright,
                    MelodiTheme.primaryGreen,
                  ],
                  stops: [
                    (_waveController.value - 0.3).clamp(0.0, 1.0),
                    _waveController.value,
                    (_waveController.value + 0.3).clamp(0.0, 1.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PulseStorageMeter extends StatefulWidget {
  final double used;
  final double total;

  const PulseStorageMeter({
    super.key,
    required this.used,
    required this.total,
  });

  @override
  State<PulseStorageMeter> createState() => _PulseStorageMeterState();
}

class _PulseStorageMeterState extends State<PulseStorageMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.used / widget.total;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: MelodiTheme.surfaceBright,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: MelodiTheme.primaryGreen.withValues(
                  alpha: 0.6 + _pulseController.value * 0.4,
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: MelodiTheme.primaryGreen.withValues(
                      alpha: 0.1 + _pulseController.value * 0.2,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
