import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/image_with_fallback.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<SongModel> _songs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final db = DatabaseService.instance;
    final songs = <SongModel>[];
    for (final id in widget.playlist.songIds) {
      final song = await db.getSongById(id);
      if (song != null) songs.add(song);
    }
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded,
                color: AppTheme.textSecondary),
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  _showRenameDialog(context);
                  break;
                case 'delete':
                  _confirmDelete(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(AppLocale.tr('rename_playlist')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(AppLocale.tr('delete_playlist')),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _songs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add_rounded,
                          size: 64, color: AppTheme.textTertiary),
                      SizedBox(height: 16),
                      Text(
                        AppLocale.tr('no_songs_in_playlist'),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocale.tr('add_songs_from_library'),
                        style: const TextStyle(color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Playlist header
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.darkCard,
                                  AppTheme.darkCardHover,
                                ],
                              ),
                            ),
                            child: const Icon(Icons.playlist_play_rounded,
                                size: 48, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_songs.length} ${AppLocale.tr('songs').toLowerCase()}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 36,
                                  child: FilledButton.icon(
                                    onPressed: () => context
                                        .read<PlayerProvider>()
                                        .playFromQueue(_songs, 0),
                                    icon: const Icon(Icons.play_arrow_rounded,
                                        size: 20),
                                    label: Text(AppLocale.tr('play')),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppTheme.darkDivider, height: 1),
                    // Songs list
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: _songs.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          final song = _songs.removeAt(oldIndex);
                          _songs.insert(newIndex, song);
                          context
                              .read<PlaylistProvider>()
                              .reorderPlaylist(
                                  playlist.id, oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final song = _songs[index];
                          final isPlaying =
                              context.watch<PlayerProvider>().currentSong?.id ==
                                  song.id;
                          return Dismissible(
                            key: ValueKey('pl_${playlist.id}_${song.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppTheme.errorColor,
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) {
                              context
                                  .read<PlaylistProvider>()
                                  .removeSongFromPlaylist(playlist.id, song.id);
                              _songs.removeAt(index);
                            },
                            child: SongTile(
                              song: song,
                              isPlaying: isPlaying,
                              onTap: () => context
                                  .read<PlayerProvider>()
                                  .playFromQueue(_songs, index),
                              onFavorite: () => context
                                  .read<LibraryProvider>()
                                  .toggleFavorite(song),
                              showArtwork: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.playlist.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(AppLocale.tr('rename_playlist'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context
                    .read<PlaylistProvider>()
                    .renamePlaylist(widget.playlist.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text(AppLocale.tr('rename'),
                style: const TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(AppLocale.tr('delete_playlist'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '${AppLocale.tr('delete')} "${widget.playlist.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<PlaylistProvider>()
                  .deletePlaylist(widget.playlist.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(AppLocale.tr('delete'),
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
