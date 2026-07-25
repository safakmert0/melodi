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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _waveController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _noteController1;
  late AnimationController _noteController2;
  late AnimationController _noteController3;
  late AnimationController _noteController4;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _noteController1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _noteController2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _noteController3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _noteController4 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _logoController.forward();
    _waveController.repeat();
    _pulseController.repeat(reverse: true);
    _progressController.forward();
    _noteController1.repeat();
    _noteController2.repeat();
    _noteController3.repeat();
    _noteController4.repeat();

    _progressController.addListener(() {
      final progress = _progressController.value;
      setState(() {
        if (progress < 0.35) {
          _statusText = AppLocale.tr('signal_path_preparing');
        } else if (progress < 0.75) {
          _statusText = AppLocale.tr('scanning_library');
        } else {
          _statusText = AppLocale.tr('enjoy_listening');
        }
      });
    });

    await _progressController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _waveController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    _noteController1.dispose();
    _noteController2.dispose();
    _noteController3.dispose();
    _noteController4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: Stack(
        children: [
          // Floating music notes
          ...List.generate(4, (i) => _buildFloatingNote(i)),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with waves
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ...List.generate(4, (i) => _buildWave(i)),
                    _buildLogo(),
                  ],
                ),
                const SizedBox(height: 56),
                // App name
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _logoController,
                    curve: const Interval(0.3, 1.0),
                  ),
                  child: Text(
                    'Melodi',
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: MelodiTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _logoController,
                    curve: const Interval(0.5, 1.0),
                  ),
                  child: Text(
                    'Your Music. Your Way.',
                    style: TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: MelodiTheme.onSurfaceVariant.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                // Progress bar
                _buildProgressBar(),
                const SizedBox(height: 20),
                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    style: TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNote(int index) {
    final controllers = [
      _noteController1,
      _noteController2,
      _noteController3,
      _noteController4
    ];
    final icons = [
      Icons.music_note_rounded,
      Icons.queue_music_rounded,
      Icons.library_music_rounded,
      Icons.album_rounded,
    ];

    final positions = [
      const Offset(0.15, 0.2),
      const Offset(0.85, 0.3),
      const Offset(0.2, 0.7),
      const Offset(0.8, 0.75),
    ];

    return AnimatedBuilder(
      animation: controllers[index],
      builder: (context, child) {
        final progress = controllers[index].value;
        final yOffset = sin(progress * pi * 2) * 30;
        final xOffset = cos(progress * pi * 2) * 20;
        final opacity = (0.2 + sin(progress * pi * 2) * 0.15).clamp(0.0, 0.35);
        final scale = 0.8 + sin(progress * pi * 2) * 0.2;
        final rotation = sin(progress * pi * 2) * 0.3;

        return Positioned(
          left:
              MediaQuery.of(context).size.width * positions[index].dx + xOffset,
          top: MediaQuery.of(context).size.height * positions[index].dy +
              yOffset,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Icon(
                icons[index],
                size: 28,
                color: MelodiTheme.primaryGreen.withOpacity(opacity),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWave(int index) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final delay = index * 0.25;
        final progress = (_waveController.value + delay) % 1.0;
        final scale = 1.0 + progress * 2.5;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MelodiTheme.primaryGreen.withOpacity(opacity * 0.25),
                width: 1.5,
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
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _logoController,
          curve: Curves.easeOutBack,
        )),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + _pulseController.value * 0.03;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MelodiTheme.primaryGreen.withOpacity(0.15),
                      MelodiTheme.primaryGreen.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: MelodiTheme.primaryGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 36,
                  color: MelodiTheme.primaryGreen,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          width: 180,
          height: 3,
          decoration: BoxDecoration(
            color: MelodiTheme.surfaceBright.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressController.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MelodiTheme.primaryGreen, Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: MelodiTheme.primaryGreen.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
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
