import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/playback_service.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  final PlaybackService _service = PlaybackService.instance;
  StreamSubscription<SleepTimerState>? _sub;
  SleepTimerState? _state;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service.restoreSleepTimer();
    _state = SleepTimerState(remainingSeconds: _service.getRemainingTime().inSeconds, isActive: _service.isSleepTimerActive);
    _sub = _service.sleepTimerStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = _state?.isActive ?? false;
    final remaining = _state?.remainingSeconds ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 32, height: 3, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Icon(Icons.timer_outlined, size: 36, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(AppLocale.tr('sleep_timer'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
            if (isActive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(AppLocale.tr('timer_active'), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_formatDuration(remaining), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _service.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(AppLocale.tr('cancel_timer')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [15, 30, 45, 60].map((minutes) {
                  return _QuickButton(
                    label: '$minutes ${AppLocale.tr('minutes')}',
                    onTap: () {
                      _service.startSleepTimer(minutes);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: scheme.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppLocale.tr('minutes'),
                        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      final text = _customController.text.trim();
                      final minutes = int.tryParse(text);
                      if (minutes != null && minutes > 0) {
                        _service.startSleepTimer(minutes);
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onSurface,
                      foregroundColor: scheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(AppLocale.tr('apply')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
