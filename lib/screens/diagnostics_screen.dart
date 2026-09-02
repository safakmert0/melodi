import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../services/diagnostics_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, dynamic>? _bundle;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, dynamic>> _features = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final service = DiagnosticsService.instance;
      final bundle = await service.generateDiagnosticBundle();
      final errors = await service.getRecentErrors(50);
      final features = _checkFeatureStatus();
      if (mounted) {
        setState(() {
          _bundle = bundle;
          _errors = errors;
          _features = features;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _checkFeatureStatus() {
    final features = <Map<String, dynamic>>[];

    // Local playback
    features.add({
      'name': 'Yerel Şarkı Çalma',
      'status': 'working',
      'description': 'Cihazınızdaki müzik dosyalarını çalma',
    });

    // Online search
    features.add({
      'name': 'Çevrimiçi Arama',
      'status': 'working',
      'description': 'YouTube, JioSaavn, Deezer\'de şarkı arama',
    });

    // Online playback
    features.add({
      'name': 'Çevrimiçi Oynatma',
      'status': 'partial',
      'description':
          'YouTube şarkılarını doğrudan streaming ile çalma (bazen kesinti olabilir)',
    });

    // Download
    features.add({
      'name': 'İndirme',
      'status': 'working',
      'description': 'Şarkıları çevrimdışı dinlemek için indirme',
    });

    // Lyrics
    features.add({
      'name': 'Şarkı Sözleri',
      'status': 'working',
      'description': 'Senkronize şarkı sözleri görüntüleme',
    });

    // Sleep timer
    features.add({
      'name': 'Uyku Zamanlayıcı',
      'status': 'working',
      'description': 'Belirli sürede otomatik durdurma',
    });

    // Equalizer
    features.add({
      'name': 'Ekolayzır',
      'status': 'working',
      'description': 'Ses ayarları ve presetleri',
    });

    // Crossfade
    features.add({
      'name': 'Crossfade',
      'status': 'working',
      'description': 'Şarkılar arası geçiş efekti',
    });

    // Background playback
    features.add({
      'name': 'Arka Plan Çalma',
      'status': 'working',
      'description': 'Uygulama arkaplandayken müzik çalma',
    });

    // Widget
    features.add({
      'name': 'Widget',
      'status': 'working',
      'description': 'Ana ekran widget\'ı ile kontrol',
    });

    return features;
  }

  Future<void> _export() async {
    try {
      final path = await DiagnosticsService.instance.exportDiagnostics();
      final file = XFile(path);
      await Share.shareXFiles([file], text: 'Melodi Diagnostics');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    await DiagnosticsService.instance.clearErrorLogs();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.tr('clear_logs')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(AppLocale.tr('diagnostics'),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bundle == null
              ? Center(
                  child: Text('Failed to load diagnostics',
                      style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _SectionTitle(AppLocale.tr('app_info')),
                    _InfoRow(
                      label:
                          '${AppLocale.tr('version')} ${AppConstants.appVersion}',
                      value: 'Build ${AppConstants.buildNumber}',
                    ),
                    _InfoRow(
                      label: 'Platform',
                      value:
                          '${_bundle!['platform']} ${_bundle!['platformVersion']}',
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(AppLocale.tr('storage')),
                    _InfoRow(
                      label: 'DB Version',
                      value: '${_bundle!['databaseVersion']}',
                    ),
                    _InfoRow(
                      label: 'DB Size',
                      value: _formatBytes(_bundle!['databaseSizeBytes'] as int),
                    ),
                    _InfoRow(
                      label: 'Songs',
                      value: '${(_bundle!['tableCounts'] as Map)['songs']}',
                    ),
                    _InfoRow(
                      label: 'Playlists',
                      value: '${(_bundle!['tableCounts'] as Map)['playlists']}',
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    _SectionTitle('ÖZELLİK DURUMU'),
                    ..._features.map((feature) {
                      final status = feature['status'] as String;
                      final isOk = status == 'working';
                      final statusIcon = isOk
                          ? Icons.check_circle_rounded
                          : status == 'partial'
                              ? Icons.warning_rounded
                              : Icons.error_rounded;
                      final statusText = isOk
                          ? 'Çalışıyor'
                          : status == 'partial'
                              ? 'Kısmi'
                              : 'Çalışmıyor';
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon,
                                color: colors.onSurfaceVariant, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature['name'] as String,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    feature['description'] as String,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.outlineVariant),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    _SectionTitle(AppLocale.tr('error_logs')),
                    if (_errors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'No errors logged',
                          style: TextStyle(
                              color: MelodiTheme.onSurfaceVariant,
                              fontSize: 14),
                        ),
                      )
                    else
                      ...List.generate(_errors.length, (i) {
                        final error = _errors[i];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                      border:
                                          Border.all(color: colors.outlineVariant),
                                    ),
                                    child: Text(
                                      '#${_errors.length - i}',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      error['context'] as String? ?? '',
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(
                                        error['createdAt'] as String? ?? ''),
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                error['message'] as String? ?? '',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (error['stackTrace'] != null &&
                                  (error['stackTrace'] as String)
                                      .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _showStackTrace(
                                      context, error['stackTrace'] as String),
                                  child: Text(
                                    'View stack trace',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    if (_errors.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _clearLogs,
                            icon: const Icon(Icons.delete_sweep_rounded,
                                size: 18),
                            label: Text(AppLocale.tr('clear_logs')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                              side: BorderSide(
                                  color: colors.error.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _export,
                          icon: const Icon(Icons.file_upload_rounded, size: 18),
                          label: Text(AppLocale.tr('export_diagnostics')),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.onSurface,
                            foregroundColor: colors.surface,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  void _showStackTrace(BuildContext context, String trace) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Stack Trace',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    trace,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: MelodiTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
  }) : valueColor = null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? MelodiTheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
