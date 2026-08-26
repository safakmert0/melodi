import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<SongModel> _songs;
  bool _isLoading = true;
  bool _syncEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadSyncState();
  }

  Future<void> _loadSyncState() async {
    final state =
        await DatabaseService.instance.getPlaylistSyncState(widget.playlist.id);
    if (mounted) {
      setState(() {
        _syncEnabled =
            state != null ? (state['syncEnabled'] as int?) == 1 : false;
      });
    }
  }

  Future<void> _rematchAll() async {
    // Playlist rematching was powered by Spotify/YTMusic account matching and
    // has been removed.
    return;
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
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded,
                color: MelodiTheme.onSurfaceVariant),
            onSelected: (value) async {
              switch (value) {
                case 'add':
                  _showAddSongsSheet(context);
                  break;
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
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add,
                        size: 20, color: MelodiTheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(AppLocale.tr('add_songs')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 20, color: MelodiTheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(AppLocale.tr('rename_playlist')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 20, color: MelodiTheme.errorRed),
                    const SizedBox(width: 8),
                    Text(AppLocale.tr('delete_playlist'),
                        style: TextStyle(color: MelodiTheme.errorRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: MelodiTheme.primaryGreen))
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add_rounded,
                          size: 64, color: MelodiTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        AppLocale.tr('no_songs_in_playlist'),
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocale.tr('add_songs_from_library'),
                        style: TextStyle(color: MelodiTheme.textMuted),
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
                              gradient: _songs.isNotEmpty &&
                                      _songs.first.albumArt != null
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        MelodiTheme.containerLow,
                                        MelodiTheme.surfaceHigh,
                                      ],
                                    ),
                            ),
                            child: _songs.isNotEmpty &&
                                    _songs.first.albumArt != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _songs.first.albumArt!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(Icons.playlist_play_rounded,
                                    size: 48, color: MelodiTheme.primaryGreen),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.name,
                                  style: TextStyle(
                                    color: MelodiTheme.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_songs.length} ${AppLocale.tr('songs').toLowerCase()}',
                                  style: TextStyle(
                                    color: MelodiTheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 36,
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => context
                                        .read<PlayerProvider>()
                                        .playFromQueue(_songs, 0),
                                    icon: const Icon(Icons.play_arrow_rounded,
                                        size: 20),
                                    label: Text(AppLocale.tr('play')),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MelodiTheme.primaryGreen,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_songs.any(_isRemoteSong)) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 36,
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _downloadPlaylist,
                                      icon: const Icon(
                                        Icons.download_for_offline_rounded,
                                        size: 18,
                                      ),
                                      label: Text(AppLocale.tr('download_all')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: MelodiTheme.onSurface,
                                        side: BorderSide(
                                          color: MelodiTheme.outlineVariant,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: MelodiTheme.outlineVariant, height: 1),
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
                              .reorderPlaylist(playlist.id, oldIndex, newIndex);
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
                              color: MelodiTheme.errorRed,
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) {
                              context
                                  .read<PlaylistProvider>()
                                  .removeSongFromPlaylist(playlist.id, song.id);
                              setState(() => _songs.removeAt(index));
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
                              onViewAlbum: () =>
                                  _navigateToAlbum(context, song),
                              onViewArtist: () =>
                                  _navigateToArtist(context, song),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  bool _isRemoteSong(SongModel song) =>
      song.filePath.startsWith('spotify://') ||
      song.filePath.startsWith('youtube://') ||
      song.filePath.startsWith('http://') ||
      song.filePath.startsWith('https://');

  void _downloadPlaylist() {
    final downloads = context.read<DownloadProvider>();
    final seenSourceIds = <String>{};
    final queued = <Map<String, String>>[];

    for (final song in _songs.where(_isRemoteSong)) {
      final status = downloads.getStatusForSong(song.title, song.artist);
      if (status != null && status != DownloadState.failed) continue;

      var sourceId = song.id;
      for (final prefix in const ['spotify:', 'youtube:']) {
        if (sourceId.startsWith(prefix)) {
          sourceId = sourceId.substring(prefix.length);
          break;
        }
      }
      if (!seenSourceIds.add(sourceId)) continue;
      queued.add({
        'id': sourceId,
        'title': song.title,
        'artist': song.artist,
        'durationMs': song.duration.inMilliseconds.toString(),
        if (song.album.isNotEmpty) 'album': song.album,
      });
    }

    if (queued.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.tr('download_already_queued'))),
      );
      return;
    }

    downloads.enqueuePlaylist(queued);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${queued.length} ${AppLocale.tr('songs').toLowerCase()} · ${AppLocale.tr('download_queued')}",
        ),
        backgroundColor: MelodiTheme.primaryGreen,
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.playlist.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(AppLocale.tr('rename_playlist'),
            style: TextStyle(color: MelodiTheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: MelodiTheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: MelodiTheme.containerLow,
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
                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
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
                style: TextStyle(color: MelodiTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  void _navigateToAlbum(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final albums = lib.albums
        .where((a) => a.name == song.album && a.artist == song.artist)
        .toList();
    if (albums.isEmpty) return;
    final albumSongs = lib.getSongsForAlbum(albums.first);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimpleAlbumScreen(
          albumName: albums.first.name,
          artistName: albums.first.artist,
          artwork: albums.first.artwork,
          songs: albumSongs,
        ),
      ),
    );
  }

  void _navigateToArtist(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final artists = lib.artists.where((a) => a.name == song.artist).toList();
    if (artists.isEmpty) return;
    final artistSongs = lib.getSongsForArtist(artists.first);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimpleArtistScreen(
          artistName: artists.first.name,
          songs: artistSongs,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MelodiTheme.containerLow,
        title: Text(AppLocale.tr('delete_playlist'),
            style: TextStyle(color: MelodiTheme.onSurface)),
        content: Text(
          '${AppLocale.tr('delete')} "${widget.playlist.name}"?',
          style: TextStyle(color: MelodiTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocale.tr('cancel'),
                style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
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
                style: TextStyle(color: MelodiTheme.errorRed)),
          ),
        ],
      ),
    );
  }


  void _showAddSongsSheet(BuildContext context) {
    final library = context.read<LibraryProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    final existingIds = widget.playlist.songIds.toSet();
    final available =
        library.songs.where((s) => !existingIds.contains(s.id)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MelodiTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(AppLocale.tr('add_songs'),
                            style: TextStyle(
                                color: MelodiTheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (selected.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              final songIds = selected.toList();
                              playlistProvider.addSongsToPlaylist(
                                  widget.playlist.id, songIds);
                              setState(() => _songs.addAll(available
                                  .where((s) => selected.contains(s.id))));
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              '${AppLocale.tr('add')} (${selected.length})',
                              style: TextStyle(color: MelodiTheme.primaryGreen),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(color: MelodiTheme.outlineVariant, height: 1),
                  Expanded(
                    child: available.isEmpty
                        ? Center(
                            child: Text(AppLocale.tr('all_songs_added'),
                                style: TextStyle(
                                    color: MelodiTheme.onSurfaceVariant)))
                        : ListView.builder(
                            itemCount: available.length,
                            itemBuilder: (context, index) {
                              final song = available[index];
                              final isSelected = selected.contains(song.id);
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: song.albumArt != null
                                      ? MemoryImage(song.albumArt!)
                                      : null,
                                  child: song.albumArt == null
                                      ? Icon(Icons.music_note_rounded,
                                          color: MelodiTheme.textMuted,
                                          size: 20)
                                      : null,
                                ),
                                title: Text(song.title,
                                    style: TextStyle(
                                        color: MelodiTheme.onSurface)),
                                subtitle: Text(song.artist,
                                    style: TextStyle(
                                        color: MelodiTheme.onSurfaceVariant)),
                                trailing: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? MelodiTheme.primaryGreen
                                      : MelodiTheme.textMuted,
                                ),
                                onTap: () {
                                  setSheetState(() {
                                    if (isSelected) {
                                      selected.remove(song.id);
                                    } else {
                                      selected.add(song.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SimpleAlbumScreen extends StatelessWidget {
  final String albumName;
  final String artistName;
  final Uint8List? artwork;
  final List<SongModel> songs;

  const _SimpleAlbumScreen({
    required this.albumName,
    required this.artistName,
    this.artwork,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(title: Text(albumName)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () =>
                context.read<PlayerProvider>().playFromQueue(songs, index),
            onFavorite: () =>
                context.read<LibraryProvider>().toggleFavorite(song),
            onViewArtist: () => _navigateToArtist(context, song),
          );
        },
      ),
    );
  }

  void _navigateToArtist(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final artists = lib.artists.where((a) => a.name == song.artist).toList();
    if (artists.isEmpty) return;
    final artistSongs = lib.getSongsForArtist(artists.first);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimpleArtistScreen(
          artistName: artists.first.name,
          songs: artistSongs,
        ),
      ),
    );
  }
}

class _SimpleArtistScreen extends StatelessWidget {
  final String artistName;
  final List<SongModel> songs;

  const _SimpleArtistScreen({
    required this.artistName,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(title: Text(artistName)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () =>
                context.read<PlayerProvider>().playFromQueue(songs, index),
            onFavorite: () =>
                context.read<LibraryProvider>().toggleFavorite(song),
            onViewAlbum: () => _navigateToAlbum(context, song),
          );
        },
      ),
    );
  }

  void _navigateToAlbum(BuildContext context, SongModel song) {
    final lib = context.read<LibraryProvider>();
    final albums = lib.albums
        .where((a) => a.name == song.album && a.artist == song.artist)
        .toList();
    if (albums.isEmpty) return;
    final albumSongs = lib.getSongsForAlbum(albums.first);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimpleAlbumScreen(
          albumName: albums.first.name,
          artistName: albums.first.artist,
          artwork: albums.first.artwork,
          songs: albumSongs,
        ),
      ),
    );
  }
}
