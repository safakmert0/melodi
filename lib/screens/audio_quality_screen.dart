import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/audio_quality_service.dart';
import '../services/database_service.dart';

class AudioQualityScreen extends StatefulWidget {
  const AudioQualityScreen({super.key});

  @override
  State<AudioQualityScreen> createState() => _AudioQualityScreenState();
}

class _AudioQualityScreenState extends State<AudioQualityScreen> {
  final AudioQualityService _service = AudioQualityService();
  final DatabaseService _db = DatabaseService.instance;

  String _streamingQuality = 'auto';
  String _downloadQuality = 'high';
  String _cellularQuality = 'auto';
  String _wifiQuality = 'high';
  bool _keepDownloads = true;
  int? _autoDeleteDays;

  static const _qualityOptions = ['auto', 'low', 'normal', 'high', 'lossless'];
  static const _downloadOptions = ['normal', 'high', 'lossless'];
  static const _autoDeleteOptions = [null, 7, 30, 90];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final streaming = await _service.getStreamingQuality();
    final download = await _service.getDownloadQuality();
    final cellular = await _service.getCellularQuality();
    final wifi = await _service.getWifiQuality();
    final storage = await _service.getStorageManagement();
    if (mounted) {
      setState(() {
        _streamingQuality = streaming;
        _downloadQuality = download;
        _cellularQuality = cellular;
        _wifiQuality = wifi;
        _keepDownloads = storage['keepDownloads'] as bool;
        _autoDeleteDays = storage['autoDeleteDays'] as int?;
      });
    }
  }

  String _qualityLabel(String key) {
    switch (key) {
      case 'auto': return AppLocale.tr('quality_auto');
      case 'low': return AppLocale.tr('quality_low');
      case 'normal': return AppLocale.tr('quality_normal');
      case 'high': return AppLocale.tr('quality_high');
      case 'lossless': return AppLocale.tr('quality_lossless');
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('audio_quality')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(AppLocale.tr('streaming_quality')),
          _QualitySelector(
            options: _qualityOptions,
            value: _streamingQuality,
            labelFn: _qualityLabel,
            onChanged: (v) {
              setState(() => _streamingQuality = v);
              _service.setStreamingQuality(v);
            },
          ),
          const SizedBox(height: 16),
          _SectionHeader(AppLocale.tr('download_quality')),
          _QualitySelector(
            options: _downloadOptions,
            value: _downloadQuality,
            labelFn: _qualityLabel,
            onChanged: (v) {
              setState(() => _downloadQuality = v);
              _service.setDownloadQuality(v);
            },
          ),
          const SizedBox(height: 16),
          _SectionHeader(AppLocale.tr('cellular_quality')),
          _QualitySelector(
            options: _qualityOptions,
            value: _cellularQuality,
            labelFn: _qualityLabel,
            onChanged: (v) {
              setState(() => _cellularQuality = v);
              _service.setCellularQuality(v);
            },
          ),
          const SizedBox(height: 16),
          _SectionHeader(AppLocale.tr('wifi_quality')),
          _QualitySelector(
            options: _qualityOptions,
            value: _wifiQuality,
            labelFn: _qualityLabel,
            onChanged: (v) {
              setState(() => _wifiQuality = v);
              _service.setWifiQuality(v);
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader(AppLocale.tr('storage_management')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocale.tr('keep_downloads'),
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                    ],
                  ),
                ),
                Switch(
                  value: _keepDownloads,
                  onChanged: (v) {
                    setState(() => _keepDownloads = v);
                    _service.setStorageManagement(keepDownloads: v);
                  },
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocale.tr('auto_delete'),
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                    ],
                  ),
                ),
                DropdownButton<int?>(
                  value: _autoDeleteDays,
                  dropdownColor: AppTheme.surface,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  underline: const SizedBox.shrink(),
                  items: _autoDeleteOptions.map((days) {
                    return DropdownMenuItem<int?>(
                      value: days,
                      child: Text(
                        days == null
                            ? AppLocale.tr('never')
                            : '${days} ${AppLocale.tr('days')}',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => _autoDeleteDays = v);
                    _service.setStorageManagement(autoDeleteDays: v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _QualitySelector extends StatelessWidget {
  final List<String> options;
  final String value;
  final String Function(String) labelFn;
  final ValueChanged<String> onChanged;

  const _QualitySelector({
    required this.options,
    required this.value,
    required this.labelFn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((option) {
            final selected = value == option;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labelFn(option)),
                selected: selected,
                onSelected: (_) => onChanged(option),
                selectedColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.black : AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
