import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/library_provider.dart';
import '../services/ffmpeg_ringtone_service.dart';

class VideoToolsScreen extends StatefulWidget {
  const VideoToolsScreen({super.key});

  @override
  State<VideoToolsScreen> createState() => _VideoToolsScreenState();
}

class _VideoToolsScreenState extends State<VideoToolsScreen> {
  File? _selectedVideo;
  double _videoDuration = 0;
  double _startTime = 0;
  double _endTime = 30;
  bool _isProcessing = false;
  String? _outputPath;
  String _ringtoneName = 'Ringtone';
  String _status = '';
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _ringtoneName);
    _loadRingtoneName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadRingtoneName() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync();
    final videoFiles = files.where((f) => f is File && _isVideoFile(f.path)).toList();
    if (videoFiles.isNotEmpty) {
      // Could auto-suggest from recent video
    }
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final duration = await FFmpegRingtoneService.getVideoDuration(file.path);
        setState(() {
          _selectedVideo = file;
          _videoDuration = duration ?? 30;
          _endTime = _videoDuration.clamp(0, 30);
          _status = 'Video seçildi: ${file.path.split('/').last}';
        });
      }
    } catch (e) {
      setState(() => _status = 'Hata: $e');
    }
  }

  Future<void> _extractAudio() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isProcessing = true;
      _status = 'Ses çıkarılıyor...';
      _outputPath = null;
    });

    final path = await FFmpegRingtoneService.extractAudio(
      inputPath: _selectedVideo!.path,
      startTime: _startTime,
      duration: _endTime - _startTime,
      outputFormat: 'm4a',
    );

    setState(() {
      _isProcessing = false;
      if (path != null) {
        _outputPath = path;
        _status = 'Ses çıkarıldı: ${path.split('/').last}';
      } else {
        _status = 'Ses çıkarma başarısız';
      }
    });
  }

  Future<void> _saveAsRingtone() async {
    if (_outputPath == null) return;

    setState(() {
      _isProcessing = true;
      _status = 'Zil sesi oluşturuluyor...';
    });

    final result = await FFmpegRingtoneService.saveAsRingtone(
      audioPath: _outputPath!,
      ringtoneName: _ringtoneName,
      startTime: 0,
      duration: _endTime - _startTime,
    );

    setState(() {
      _isProcessing = false;
    });

    if (result != null && mounted) {
      setState(() => _status = 'Zil sesi hazır! Paylaş butonuna basın.');
      _showRingtoneSavedDialog(result);
    } else {
      setState(() => _status = 'Zil sesi oluşturulamadı');
    }
  }

  Future<void> _extractAndSaveRingtone() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isProcessing = true;
      _status = 'Video işlenip zil sesi oluşturuluyor...';
    });

    final result = await FFmpegRingtoneService.extractAndSaveAsRingtone(
      videoPath: _selectedVideo!.path,
      ringtoneName: _ringtoneName,
      startTime: _startTime,
      duration: _endTime - _startTime,
    );

    setState(() {
      _isProcessing = false;
    });

    if (result != null && mounted) {
      setState(() => _status = 'Zil sesi hazır! Paylaş butonuna basın.');
      _showRingtoneSavedDialog(result);
    } else {
      setState(() => _status = 'İşlem başarısız');
    }
  }

  Future<void> _addToLibrary() async {
    if (_outputPath == null) return;

    try {
      final library = context.read<LibraryProvider>();
      await library.importFromFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitaplığa eklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _showRingtoneSavedDialog(RingtoneResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zil Sesi Oluşturuldu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İsim: ${result.name}'),
            Text('Süre: ${result.duration.toStringAsFixed(1)} sn'),
            const SizedBox(height: 12),
            const Text(
              'iOS\'ta zil sesi olarak kaydetmek için:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('1. "Paylaş" butonuna basın'),
            const Text('2. "Dosyalara Kaydet" seçin'),
            const Text('3. Ayarlar > Ses ve Titreşim > Zil Sesi\'ne gidin'),
            const Text('4. Oluşturulan ses dosyasını seçin'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Paylaş'),
            onPressed: () {
              Navigator.pop(context);
              FFmpegRingtoneService.shareRingtone(result);
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canProcess = _selectedVideo != null && !_isProcessing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Araçları'),
        actions: [
          if (_outputPath != null)
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Kitaplığa Ekle',
              onPressed: _addToLibrary,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Video Seç', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (_selectedVideo == null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.video_file_rounded),
                          label: const Text('Video Dosyası Seç'),
                          onPressed: _pickVideo,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedVideo!.path.split('/').last,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Süre: ${_formatTime(_videoDuration)}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.change_circle_rounded),
                            label: const Text('Değiştir'),
                            onPressed: _pickVideo,
                          ),
                        ],
                      ),
                    ],
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _status.contains('Hata') || _status.contains('başarısız')
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time Range Selection
            if (_selectedVideo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zaman Aralığı (Max 30 sn)', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      // Start Time
                      Row(
                        children: [
                          const Text('Başlangıç: '),
                          Expanded(
                            child: Slider(
                              value: _startTime,
                              min: 0,
                              max: (_videoDuration - 1).clamp(1, _videoDuration),
                              divisions: ((_videoDuration - 1).clamp(1, _videoDuration) * 10).round(),
                              label: _formatTime(_startTime),
                              onChanged: (v) => setState(() => _startTime = v),
                            ),
                          ),
                          Text(_formatTime(_startTime), style: theme.textTheme.bodySmall),
                        ],
                      ),
                      // End Time
                      Row(
                        children: [
                          const Text('Bitiş:     '),
                          Expanded(
                            child: Slider(
                              value: _endTime,
                              min: (_startTime + 1).clamp(1, _videoDuration),
                              max: (_startTime + 30).clamp(_startTime + 1, _videoDuration),
                              divisions: ((_startTime + 30).clamp(_startTime + 1, _videoDuration) - _startTime).round() * 10,
                              label: _formatTime(_endTime),
                              onChanged: (v) => setState(() => _endTime = v),
                            ),
                          ),
                          Text(_formatTime(_endTime), style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seçilen süre: ${(_endTime - _startTime).toStringAsFixed(1)} sn',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Zil Sesi Adı',
                          hintText: 'Ringtone',
                          prefixIcon: Icon(Icons.music_note_rounded),
                        ),
                        onChanged: (v) => setState(() => _ringtoneName = v),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('İşlemler', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      // Extract Audio
                      FilledButton.icon(
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.audio_file_rounded),
                        label: Text(_isProcessing ? 'İşleniyor...' : 'Sesi Çıkar (.m4a)'),
                        onPressed: canProcess ? _extractAudio : null,
                      ),
                      const SizedBox(height: 8),
                      // Save as Ringtone (if audio extracted)
                      if (_outputPath != null) ...[
                        FilledButton.icon(
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_isProcessing ? 'İşleniyor...' : 'Zil Sesi Oluştur (.m4r)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiary,
                          ),
                          onPressed: _isProcessing ? null : _saveAsRingtone,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.library_add_rounded),
                          label: const Text('Kitaplığa Ekle'),
                          onPressed: _addToLibrary,
                        ),
                      ] else ...[
                        // Extract and Save Ringtone in one step
                        FilledButton.icon(
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.music_note_rounded),
                          label: Text(_isProcessing ? 'İşleniyor...' : 'Video\'dan Zil Sesi Oluştur'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                          ),
                          onPressed: canProcess ? _extractAndSaveRingtone : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info Card
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Nasıl Kullanılır?', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Videonuzu seçin (MP4, MOV, MKV vb.)'),
                      const Text('2. Zil sesi için 30 sn\'lik bir aralık seçin'),
                      const Text('3. "Zil Sesi Oluştur" butonuna basın'),
                      const Text('4. Paylaş butonuna basıp "Dosyalara Kaydet" deyin'),
                      const Text('5. Ayarlar > Ses ve Titreşim > Zil Sesi\'nden seçin'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}