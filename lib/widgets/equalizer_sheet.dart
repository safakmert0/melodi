import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../services/playback_service.dart';
import '../providers/player_provider.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  final PlaybackService _service = PlaybackService.instance;
  String _activePreset = 'normal';
  List<double> _customBands = List.filled(10, 0);
  List<double> _currentBands = List.filled(10, 0);
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preset = await _service.getActiveEQPreset();
    final enabled = await _service.getEQEnabled();
    final custom = await _service.getCustomEQ();
    if (mounted) {
      setState(() {
        _activePreset = preset;
        _enabled = enabled;
        _customBands = List.from(custom);
        _currentBands = _getBandsForPreset(preset);
        _loaded = true;
      });
    }
  }

  List<double> _getBandsForPreset(String name) {
    if (name == 'custom') return _customBands;
    final presets = PlaybackService.equalizerPresets;
    final match = presets.firstWhere((p) => p.name == name, orElse: () => presets.first);
    return match.bands;
  }

  void _applyPreset(String name) {
    final bands = _getBandsForPreset(name);
    setState(() {
      _activePreset = name;
      _currentBands = List.from(bands);
    });
  }

  Future<void> _saveAndApply() async {
    final handler = context.read<PlayerProvider>().handler;
    if (_activePreset == 'custom') {
      await _service.setCustomEQ(_currentBands);
      for (int i = 0; i < _currentBands.length && i < 10; i++) {
        await handler.setEqualizerBand(i, _currentBands[i]);
      }
    } else {
      await _service.setEqualizerPreset(_activePreset);
      await handler.applyEqualizerPreset(_activePreset);
    }
    await _service.setEQEnabled(_enabled);
    await handler.setEqualizerEnabled(_enabled);
  }

  void _resetToFlat() {
    setState(() {
      _activePreset = 'normal';
      _currentBands = List.filled(10, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_loaded) {
      return const SafeArea(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (Platform.isIOS) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 32, height: 3, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant, size: 32),
              const SizedBox(height: 12),
              Text(AppLocale.tr('equalizer'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Ekolayzır şu anda iOS ses motoruna uygulanamıyor.\nAyarlar kaydedilir; gerçek iOS ses işleme sonraki sürümde eklenecek.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(AppLocale.tr('close')),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final presets = PlaybackService.equalizerPresets;
    final bandLabels = PlaybackService.eqBandLabels;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 32, height: 3, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(AppLocale.tr('equalizer'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(AppLocale.tr('presets').toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: presets.map((preset) {
                  final selected = _activePreset == preset.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(AppLocale.tr(preset.name), style: const TextStyle(fontSize: 12)),
                      onSelected: (_) => _applyPreset(preset.name),
                      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      selectedColor: scheme.surfaceContainerHigh,
                      backgroundColor: scheme.surfaceContainer,
                      labelStyle: TextStyle(color: selected ? scheme.onSurface : scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_enabled) ...[
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: bandLabels.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Text('${_currentBands[index] >= 0 ? '+' : ''}${_currentBands[index].toInt()}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 11)),
                          const SizedBox(height: 4),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: (_currentBands[index] + 12) / 24,
                                onChanged: (v) {
                                  setState(() {
                                    _currentBands[index] = (v * 24) - 12;
                                    _activePreset = 'custom';
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(bandLabels[index], style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 8)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resetToFlat,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text(AppLocale.tr('reset_eq')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _saveAndApply();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(AppLocale.tr('apply')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
