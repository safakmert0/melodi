import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/playback_service.dart';

class CrossfadeSlider extends StatefulWidget {
  const CrossfadeSlider({super.key});

  @override
  State<CrossfadeSlider> createState() => _CrossfadeSliderState();
}

class _CrossfadeSliderState extends State<CrossfadeSlider> {
  final PlaybackService _service = PlaybackService.instance;
  double _crossfade = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await _service.getCrossfadeDuration();
    if (mounted) {
      setState(() {
        _crossfade = d.inSeconds.toDouble();
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${AppLocale.tr('crossfade')}: ${_crossfade.toInt()}s',
          style: TextStyle(
            color: MelodiTheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _crossfade,
          min: 0,
          max: 12,
          divisions: 12,
          activeColor: MelodiTheme.primaryGreen,
          inactiveColor: MelodiTheme.outlineVariant,
          onChanged: (v) {
            setState(() => _crossfade = v);
            _service.setCrossfadeDuration(Duration(seconds: v.toInt()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0s', style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
              Text('12s', style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _crossfade == 0
              ? AppLocale.tr('off')
              : '${_crossfade.toInt()} ${AppLocale.tr('seconds')}',
          style: TextStyle(
            color: MelodiTheme.primaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
