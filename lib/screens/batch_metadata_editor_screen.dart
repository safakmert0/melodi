import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';

/// LA_Player MetadataEditor batch birebir: çoklu seçimde Title/Artist/Album toplu uygula
/// Hata: "Cannot apply same Title and Artist to multiple selected files."
class BatchMetadataEditorScreen extends StatefulWidget {
  final List<SongModel> songs;
  const BatchMetadataEditorScreen({super.key, required this.songs});
  @override
  State<BatchMetadataEditorScreen> createState() => _BatchMetadataEditorScreenState();
}

class _BatchMetadataEditorScreenState extends State<BatchMetadataEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  bool _applyTitle = false;
  bool _applyArtist = false;
  bool _applyAlbum = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _artistCtrl = TextEditingController();
    _albumCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    final album = _albumCtrl.text.trim();
    if (widget.songs.length > 1 && _applyTitle && _applyArtist && title.isNotEmpty && artist.isNotEmpty) {
      if (widget.songs.length > 1) {
        // LA_Player: Cannot apply same Title and Artist to multiple selected files.
        final same = title.isNotEmpty && artist.isNotEmpty;
        if (same) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot apply same Title and Artist to multiple selected files.')),
          );
          return;
        }
      }
    }
    final db = DatabaseService.instance;
    int updated = 0;
    for (final song in widget.songs) {
      final changes = <String, dynamic>{};
      if (_applyTitle && title.isNotEmpty) changes['title'] = title;
      if (_applyArtist && artist.isNotEmpty) changes['artist'] = artist;
      if (_applyAlbum && album.isNotEmpty) changes['album'] = album;
      if (changes.isEmpty) continue;
      await db.updateTrackMetadata(song.id, changes);
      updated++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated $updated of ${widget.songs.length} tracks')));
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Metadata')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Selected ${widget.songs.length} tracks', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _applyTitle,
            onChanged: (v) => setState(() => _applyTitle = v ?? false),
            title: const Text('Title', style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _titleCtrl,
            enabled: _applyTitle,
            decoration: const InputDecoration(hintText: 'New title for all', border: OutlineInputBorder()),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _applyArtist,
            onChanged: (v) => setState(() => _applyArtist = v ?? false),
            title: const Text('Artist', style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _artistCtrl,
            enabled: _applyArtist,
            decoration: const InputDecoration(hintText: 'New artist for all', border: OutlineInputBorder()),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _applyAlbum,
            onChanged: (v) => setState(() => _applyAlbum = v ?? false),
            title: const Text('Album', style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _albumCtrl,
            enabled: _applyAlbum,
            decoration: const InputDecoration(hintText: 'New album for all', border: OutlineInputBorder()),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_applyTitle || _applyArtist || _applyAlbum) ? _apply : null,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Apply to selected'),
          ),
          const SizedBox(height: 8),
          Text('LA_Player: toplu modda aynı Title+Artist birden fazla dosyaya uygulanamaz.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
