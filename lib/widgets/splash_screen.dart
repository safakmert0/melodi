import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _waveController;
  late AnimationController _progressController;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    _waveController.repeat();
    _progressController.forward();

    _progressController.addListener(() {
      final progress = _progressController.value;
      setState(() {
        if (progress < 0.4) {
          _statusText = AppLocale.tr('signal_path_preparing');
        } else if (progress < 0.8) {
          _statusText = AppLocale.tr('scanning_library');
        } else {
          _statusText = AppLocale.tr('enjoy_listening');
        }
      });
    });

    await _progressController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _waveController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (i) => _buildWave(i)),
                _buildLogo(),
              ],
            ),
            const SizedBox(height: 48),
            _buildProgressBar(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusText,
                key: ValueKey(_statusText),
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWave(int index) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final delay = index * 0.3;
        final progress = (_waveController.value + delay) % 1.0;
        final scale = 1.0 + progress * 2.0;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MelodiTheme.primaryGreen.withValues(alpha: opacity * 0.3),
                width: 2,
              ),
              gradient: RadialGradient(
                colors: [
                  MelodiTheme.primaryGreen.withValues(alpha: opacity * 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _logoController,
          curve: Curves.easeOutBack,
        )),
        child: const Text(
          'Melodi',
          style: TextStyle(
            fontFamily: AppConstants.fontFamily,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: MelodiTheme.onSurface,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 4,
          decoration: BoxDecoration(
            color: MelodiTheme.surfaceBright,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressController.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.transparent, MelodiTheme.primaryGreen],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: MelodiTheme.primaryGreen.withValues(alpha: 0.5),
                    blurRadius: 10,
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
