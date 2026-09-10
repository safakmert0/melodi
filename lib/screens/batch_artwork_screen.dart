import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/artwork_service.dart';
import '../services/artwork_embedding_service.dart';
import '../services/database_service.dart';

/// LA_Player Batch search and apply artwork birebir
class BatchArtworkScreen extends StatefulWidget {
  final List<SongModel> songs;
  const BatchArtworkScreen({super.key, required this.songs});
  @override
  State<BatchArtworkScreen> createState() => _BatchArtworkScreenState();
}

class _BatchArtworkScreenState extends State<BatchArtworkScreen> {
  late List<SongModel> _songs;
  final Map<String, Uint8List?> _found = {};
  final Map<String, Uint8List?> _selected = {};
  int _searchingIndex = -1;
  bool _autoDownload = true;
  int _applied = 0;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.songs);
    if (_autoDownload) _startBatchSearch();
  }

  Future<void> _startBatchSearch() async {
    for (var i = 0; i < _songs.length; i++) {
      if (!mounted) return;
      setState(() => _searchingIndex = i);
      final song = _songs[i];
      final bytes = await ArtworkService.fetchArtwork(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (!mounted) return;
      setState(() {
        _found[song.id] = bytes;
        if (bytes != null && _autoDownload) _selected[song.id] = bytes;
      });
    }
    if (mounted) setState(() => _searchingIndex = -1);
  }

  Future<void> _applySelected() async {
    final db = DatabaseService.instance;
    int applied = 0;
    for (final song in _songs) {
      final bytes = _selected[song.id];
      if (bytes == null) continue;
      final ok = await ArtworkEmbeddingService.embedCoverArt(
        filePath: song.filePath,
        artwork: bytes,
      );
      if (ok) {
        await db.updateTrackAlbumArt(song.id, bytes);
        applied++;
      }
    }
    if (!mounted) return;
    setState(() => _applied = applied);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated artwork for $applied of ${_songs.length} selected items.')),
    );
    Navigator.pop(context, applied);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Artwork'),
        actions: [
          if (_searchingIndex >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text('Searching artwork ${_searchingIndex + 1}/${_songs.length}...', style: const TextStyle(fontSize: 11))),
            ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Auto-Download Artwork', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Automatically apply found artwork', style: TextStyle(fontSize: 11)),
            value: _autoDownload,
            onChanged: (v) => setState(() => _autoDownload = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, i) {
                final song = _songs[i];
                final found = _found[song.id];
                final isSearching = _searchingIndex == i;
                final thumb = found ?? song.albumArt;
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      image: thumb != null && thumb.isNotEmpty
                          ? DecorationImage(image: MemoryImage(thumb), fit: BoxFit.cover)
                          : null,
                    ),
                    child: thumb == null
                        ? Icon(Icons.image_rounded, color: cs.onSurfaceVariant, size: 20)
                        : null,
                  ),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  trailing: isSearching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Checkbox(
                          value: _selected.containsKey(song.id),
                          onChanged: found == null
                              ? null
                              : (v) => setState(() {
                                    if (v == true) _selected[song.id] = found;
                                    else _selected.remove(song.id);
                                  }),
                        ),
                  onTap: found != null
                      ? () => setState(() {
                            if (_selected.containsKey(song.id)) _selected.remove(song.id);
                            else _selected[song.id] = found;
                          })
                      : null,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_searchingIndex == -1)
                    Text('Tap an artwork to apply. ${_selected.length} selected.',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty ? null : _applySelected,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Apply to ${_selected.length} tracks'),
                  ),
                  TextButton(
                    onPressed: _searchingIndex >= 0 ? null : _startBatchSearch,
                    child: const Text('Search again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
