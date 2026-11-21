import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../services/lastfm_service.dart';

/// Last.fm hesabı bağlama / ayırma ekranı.
class LastfmScreen extends StatefulWidget {
  const LastfmScreen({super.key});

  @override
  State<LastfmScreen> createState() => _LastfmScreenState();
}

class _LastfmScreenState extends State<LastfmScreen> {
  bool _loading = true;
  bool _serverEnabled = false;
  bool _connected = false;
  String _username = '';
  String? _pendingToken;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await LastfmService.instance.isServerConfigured();
    final connected = await LastfmService.instance.isConnected();
    final user = await LastfmService.instance.username();
    if (mounted) {
      setState(() {
        _serverEnabled = enabled;
        _connected = connected;
        _username = user;
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    setState(() => _working = true);
    try {
      final (:token, :authUrl) = await LastfmService.instance.requestToken();
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() {
          _pendingToken = token;
          _working = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _confirm() async {
    final token = _pendingToken;
    if (token == null) return;
    setState(() => _working = true);
    try {
      final user = await LastfmService.instance.authenticate(token);
      if (mounted) {
        setState(() {
          _connected = true;
          _username = user;
          _pendingToken = null;
          _working = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlandı: $user')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await LastfmService.instance.disconnect();
    if (mounted) {
      setState(() {
        _connected = false;
        _username = '';
        _pendingToken = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Last.fm'),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ??
                        scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.music_note_rounded,
                        color: Colors.redAccent),
                    title: Text(
                      _connected
                          ? '@$_username'
                          : AppLocale.tr('connect_for_scrobbling'),
                    ),
                    subtitle: Text(
                      _connected
                          ? AppLocale.tr('scrobbling_enabled')
                          : AppLocale.tr('scrobbling_subtitle'),
                    ),
                    trailing: _connected
                        ? IconButton(
                            icon: const Icon(Icons.link_off_rounded),
                            tooltip: AppLocale.tr('disconnect'),
                            onPressed: _working ? null : _disconnect,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_serverEnabled) ...[
                  Text(
                    'Last.fm anahtarları sunucuda yapılandırılmamış. '
                    'Backend ortamına LASTFM_API_KEY / LASTFM_API_SECRET ekleyin.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ] else if (!_connected) ...[
                  if (_pendingToken == null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _connect,
                        icon: const Icon(Icons.link_rounded),
                        label: Text(AppLocale.tr('connect')),
                      ),
                    )
                  else ...[
                    Text(
                      'Tarayıcıda açılan sayfada hesabınıza onaylayın, '
                      'sonra aşağıdaki düğmeye basın.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _confirm,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(AppLocale.tr('confirm')),
                      ),
                    ),
                  ],
                ],
                if (_working) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }
}
