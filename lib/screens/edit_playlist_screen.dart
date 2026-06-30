import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../models/playlist_model.dart';
import '../providers/playlist_provider.dart';
import '../providers/library_provider.dart';
import '../models/song_model.dart';

class EditPlaylistScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const EditPlaylistScreen({super.key, required this.playlist});

  @override
  State<EditPlaylistScreen> createState() => _EditPlaylistScreenState();
}

class _EditPlaylistScreenState extends State<EditPlaylistScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late List<SongModel> _songs;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _descController = TextEditingController(text: widget.playlist.description ?? '');
    _songs = List.from(widget.playlist.songs ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocale.tr('cancel'),
            style: const TextStyle(
              fontFamily: AppConstants.fontFamily,
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          AppLocale.tr('edit_playlist'),
          style: MelodiTheme.heading(size: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              AppLocale.tr('done'),
              style: const TextStyle(
                fontFamily: AppConstants.fontFamily,
                color: MelodiTheme.primaryGreen,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: MelodiTheme.surfaceMid2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.queue_music_rounded, size: 60, color: MelodiTheme.onSurfaceVariant),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 20, color: MelodiTheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: AppLocale.tr('playlist_name'),
                      labelStyle: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        color: MelodiTheme.onSurfaceVariant,
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: MelodiTheme.primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurface,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: AppLocale.tr('description'),
                      labelStyle: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        color: MelodiTheme.onSurfaceVariant,
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: MelodiTheme.primaryGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_songs.length} ${AppLocale.tr('songs')}',
                    style: MelodiTheme.label(size: 12, letterSpacing: 0.1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _songs.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final song = _songs.removeAt(oldIndex);
                  _songs.insert(newIndex, song);
                });
              },
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  key: ValueKey(song.id),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_handle_rounded, color: MelodiTheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: MelodiTheme.surfaceMid2,
                        ),
                        child: song.albumArt != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(song.albumArt!, fit: BoxFit.cover, gaplessPlayback: true),
                              )
                            : const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: MelodiTheme.errorRed, size: 22),
                    onPressed: () {
                      setState(() => _songs.removeAt(index));
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final library = context.read<LibraryProvider>();
                await library.importFromFiles();
                setState(() {
                  _songs.addAll(library.songs.where((s) => !_songs.any((existing) => existing.id == s.id)));
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded, color: MelodiTheme.primaryGreen),
              label: Text(
                AppLocale.tr('add_song'),
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _save() {
    final provider = context.read<PlaylistProvider>();
    provider.updatePlaylist(
      widget.playlist.id,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      songs: _songs,
    );
    Navigator.of(context).pop();
  }
}
