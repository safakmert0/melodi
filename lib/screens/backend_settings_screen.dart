import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/backend_api_service.dart';
import '../services/database_service.dart';
import '../services/extension_service.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isChecking = false;
  bool? _isConnected;
  String? _activeExtensionUrl;

  static const String _urlKey = 'backend_api_url';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final saved =
          await DatabaseService.instance.getSetting(_urlKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _urlController.text = saved);
      }
    } catch (_) {}
    try {
      final endpoint = await ExtensionService.instance
          .resolveActiveBackendEndpoint();
      if (mounted) setState(() => _activeExtensionUrl = endpoint);
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return url;
  }

  Future<void> _checkConnection() async {
    final url = _normalizeUrl(_urlController.text);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Geçerli bir http(s) adresi gir'),
            backgroundColor: MelodiTheme.errorRed),
      );
      return;
    }

    setState(() {
      _isChecking = true;
      _isConnected = null;
    });

    // Manuel adres kaydedilir; etkin eklenti varsa o adres önceliklidir.
    BackendApiService.instance.setBaseUrl(url);
    try {
      await DatabaseService.instance.setSetting(_urlKey, url);
    } catch (_) {}

    final ok = await BackendApiService.testConnection(url);
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _isConnected = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Backend bağlantısı başarılı'
            : 'Bağlantı başarısız - sunucu çalışıyor mu?'),
        backgroundColor: ok ? MelodiTheme.primaryGreen : MelodiTheme.errorRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: const Text('Backend Settings'),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MelodiTheme.containerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dns_rounded,
                          color: MelodiTheme.primaryGreen, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'YT-DLP Backend',
                        style: TextStyle(
                            color: MelodiTheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Run a Python backend server for yt-dlp support.',
                    style: TextStyle(
                        color: MelodiTheme.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MelodiTheme.containerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status',
                      style: TextStyle(
                          color: MelodiTheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected == null
                                ? MelodiTheme.textMuted
                                : _isConnected!
                                    ? MelodiTheme.primaryGreen
                                    : MelodiTheme.errorRed),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isChecking
                            ? 'Checking...'
                            : _isConnected == null
                                ? 'Not tested yet'
                                : _isConnected!
                                    ? 'Connected'
                                    : 'Not Connected',
                        style: TextStyle(
                            color: _isConnected == null
                                ? MelodiTheme.onSurfaceVariant
                                : _isConnected!
                                    ? MelodiTheme.primaryGreen
                                    : MelodiTheme.errorRed,
                            fontSize: 14),
                      ),
                      const Spacer(),
                      if (_isChecking)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  if (_activeExtensionUrl != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Etkin eklenti önceliklidir: $_activeExtensionUrl',
                      style: TextStyle(
                          color: MelodiTheme.primaryGreen, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MelodiTheme.containerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backend URL',
                      style: TextStyle(
                          color: MelodiTheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    style: TextStyle(color: MelodiTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'http://localhost:8000',
                      hintStyle: TextStyle(color: MelodiTheme.textMuted),
                      filled: true,
                      fillColor: MelodiTheme.containerLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : _checkConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MelodiTheme.primaryGreen,
                        foregroundColor: const Color(0xFF003914),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        _isChecking ? 'Checking...' : 'Check Connection',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MelodiTheme.containerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Setup',
                      style: TextStyle(
                          color: MelodiTheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Install Python 3.8+'),
                  _buildStep('2', 'pip install -r requirements.txt'),
                  _buildStep('3', 'python main.py'),
                  _buildStep('4', 'Enter the Backend URL'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: MelodiTheme.primaryGreen, shape: BoxShape.circle),
            child: Center(
                child: Text(number,
                    style: const TextStyle(
                        color: Color(0xFF003914),
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Text(text,
              style:
                  TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    );
  }
}
