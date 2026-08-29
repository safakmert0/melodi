import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _statusText = AppLocale.tr('signal_path_preparing'));
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _statusText = AppLocale.tr('scanning_library'));
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _statusText = AppLocale.tr('enjoy_listening'));
    await Future.delayed(const Duration(milliseconds: 400));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Icon(Icons.music_note_rounded, size: 28, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text('Melodi', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Your Music. Your Way.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 2, backgroundColor: scheme.surfaceContainerHighest)),
              const SizedBox(height: 16),
              Text(_statusText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
