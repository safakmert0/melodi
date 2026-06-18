import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/playback_service.dart';

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
    if (_activePreset == 'custom') {
      await _service.setCustomEQ(_currentBands);
    } else {
      await _service.setEqualizerPreset(_activePreset);
    }
    await _service.setEQEnabled(_enabled);
  }

  void _resetToFlat() {
    setState(() {
      _activePreset = 'normal';
      _currentBands = List.filled(10, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final presets = PlaybackService.equalizerPresets;
    final bandLabels = PlaybackService.eqBandLabels;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  AppLocale.tr('equalizer'),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocale.tr('presets').toUpperCase(),
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
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
                      label: Text(
                        AppLocale.tr(preset.name),
                        style: TextStyle(fontSize: 12),
                      ),
                      onSelected: (_) => _applyPreset(preset.name),
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                      checkmarkColor: AppTheme.primaryColor,
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(
                        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            if (_enabled) ...[
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: bandLabels.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Text(
                            '${_currentBands[index] >= 0 ? '+' : ''}${_currentBands[index].toInt()}',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                                activeColor: AppTheme.primaryColor,
                                inactiveColor: AppTheme.divider,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bandLabels[index],
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resetToFlat,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text(AppLocale.tr('reset_eq')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _saveAndApply();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppLocale.tr('apply')),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
