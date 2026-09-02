import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../services/database_service.dart';
import 'playlist_import_screen.dart';

class SharedUrlsScreen extends StatefulWidget {
  const SharedUrlsScreen({super.key});

  @override
  State<SharedUrlsScreen> createState() => _SharedUrlsScreenState();
}

class _SharedUrlsScreenState extends State<SharedUrlsScreen> {
  List<Map<String, dynamic>> _urls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final urls = await db.getSharedUrls();
    if (mounted) {
      setState(() {
        _urls = urls;
        _loading = false;
      });
    }
  }

  static String _sourceLabel(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('open.spotify.com')) return 'Spotify';
    if (host.contains('music.youtube.com')) return 'YouTube Music';
    if (host.contains('youtube.com')) return 'YouTube';
    if (host.contains('youtu.be')) return 'YouTube';
    if (host.contains('soundcloud.com')) return 'SoundCloud';
    if (host.contains('music.apple.com')) return 'Apple Music';
    if (host.isEmpty) return 'Link';
    return host;
  }

  static IconData _sourceIcon(String url) {
    final source = _sourceLabel(url);
    switch (source) {
      case 'Spotify':
        return Icons.graphic_eq_rounded;
      case 'YouTube':
      case 'YouTube Music':
        return Icons.play_circle_fill_rounded;
      case 'SoundCloud':
        return Icons.cloud_queue_rounded;
      case 'Apple Music':
        return Icons.music_note_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  String _displayTitle(Map<String, dynamic> item) {
    final stored = item['title'] as String?;
    if (stored != null && stored.isNotEmpty) return stored;
    final url = item['url'] as String? ?? '';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final list = uri.queryParameters['list'];
      if (list != null && list.isNotEmpty) return 'Playlist $list';
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.last;
    }
    return url;
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final url = item['url'] as String? ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Future<void> _delete(int id) async {
    await DatabaseService.instance.deleteSharedUrl(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text('Shared Links',
            style: TextStyle(color: MelodiTheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: MelodiTheme.onSurface),
        actions: [
          IconButton(
            tooltip: AppLocale.tr('import_playlist'),
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PlaylistImportScreen()),
              );
              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocale.tr('playlist_imported')),
                    backgroundColor: MelodiTheme.primaryGreen,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: MelodiTheme.primaryGreen))
          : _urls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded,
                          size: 64, color: MelodiTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(AppLocale.tr('no_shared_links'),
                          style:
                              TextStyle(color: MelodiTheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _urls.length,
                  itemBuilder: (context, index) {
                    final item = _urls[index];
                    final url = item['url'] as String? ?? '';
                    final source = _sourceLabel(url);
                    return ListTile(
                      onTap: () => _open(item),
                      leading: Icon(_sourceIcon(url),
                          color: MelodiTheme.primaryGreen),
                      title: Text(
                        _displayTitle(item),
                        style: TextStyle(
                            color: MelodiTheme.onSurface, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$source · ${item['sharedAt'] as String}',
                        style: TextStyle(
                            color: MelodiTheme.textMuted, fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: MelodiTheme.textMuted, size: 20),
                        tooltip: 'Remove',
                        onPressed: () => _delete(item['id'] as int),
                      ),
                    );
                  },
                ),
    );
  }
}
