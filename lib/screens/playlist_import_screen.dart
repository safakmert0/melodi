import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/localization.dart';
import '../core/melodi_design.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../services/database_service.dart';
import '../services/playlist_importer.dart';

class PlaylistImportScreen extends StatefulWidget {
  const PlaylistImportScreen({super.key});

  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  PlaylistImportSource _detected = PlaylistImportSource.unknown;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    final src = PlaylistImporter.detectSource(_urlController.text);
    if (src != _detected) {
      setState(() => _detected = src);
    }
  }

  Future<void> _import() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Lütfen bir çalma listesi bağlantısı yapıştırın.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await PlaylistImporter.import(url);

    if (!mounted) return;

    if (result.isError) {
      setState(() {
        _loading = false;
        _error = result.error;
      });
      return;
    }

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (result.playlistName ?? 'İçe Aktarılan Çalma Listesi');

    final db = DatabaseService.instance;
    for (final song in result.songs) {
      await db.insertSong(song);
    }

    final provider = context.read<PlaylistProvider>();
    final playlist = await provider.createPlaylist(name);
    await provider.addSongsToPlaylist(
      playlist.id,
      result.songs.map((s) => s.id).toList(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pop(playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(AppLocale.tr('import_playlist')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MelodiSpacing.md),
        children: [
          MelodiPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocale.tr('import_playlist_hint'),
                  style: TextStyle(
                      color: colors.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'https://open.spotify.com/playlist/...',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MelodiRadius.control),
                    ),
                  ),
                ),
                if (_detected != PlaylistImportSource.unknown)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Text(
                        _sourceLabel(_detected),
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MelodiPanel(
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocale.tr('playlist_name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MelodiRadius.control),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: colors.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _loading ? null : _import,
              icon: _loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_loading
                  ? AppLocale.tr('importing')
                  : AppLocale.tr('import')),
              style: FilledButton.styleFrom(
                backgroundColor: colors.onSurface,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(PlaylistImportSource source) {
    switch (source) {
      case PlaylistImportSource.spotify:
        return 'Spotify';
      case PlaylistImportSource.youtubeMusic:
        return 'YouTube Music';
      case PlaylistImportSource.deezer:
        return 'Deezer';
      case PlaylistImportSource.unknown:
        return '';
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
