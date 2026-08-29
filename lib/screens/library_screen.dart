import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/library/library_components.dart';
import '../widgets/song_tile.dart';
import 'create_playlist_screen.dart';
import 'playlist_detail_screen.dart';
import 'profile_screen.dart';
import 'source_hub_screen.dart';
import 'video_tools_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.initialSource = LibrarySourceFilter.all,
    this.initialContent = LibraryContentFilter.songs,
    this.favoritesOnly = false,
  });

  final LibrarySourceFilter initialSource;
  final LibraryContentFilter initialContent;
  final bool favoritesOnly;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late LibrarySourceFilter _source;
  late LibraryContentFilter _content;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource;
    _content = widget.initialContent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Consumer2<LibraryProvider, PlaylistProvider>(
          builder: (context, library, playlists, _) {
            final sourceSongs = widget.favoritesOnly
                ? library.favorites
                : (_source == LibrarySourceFilter.downloads
                    ? library.downloaded
                    : library.songs);
            final songs = _source == LibrarySourceFilter.downloads
                ? List<SongModel>.from(sourceSongs)
                : sourceSongs.where(_source.matches).toList();
            final playableSongs = songs.where(_canQueue).toList();
            final totalMinutes = songs.fold<int>(
              0,
              (total, song) => total + song.duration.inMinutes,
            );
            final albums = _matchingAlbums(library, songs);
            final artists = _matchingArtists(library, songs);
            final visiblePlaylists = _matchingPlaylists(playlists, songs);

            return RefreshIndicator(
              onRefresh: library.refresh,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              child: CustomScrollView(
                key: PageStorageKey<String>(
                    'library-${_source.name}-${_content.name}-$_isGridView'),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: LibraryHeader(
                      onProfile: () => _open(const ProfileScreen()),
                      onSearch: () => _showSearch(context, library),
                      onSources: () => _open(const SourceHubScreen()),
                      onAdd: () => _showAddMenu(context, library),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: LibraryOverview(
                      songCount: songs.length,
                      albumCount: albums.length,
                      playlistCount: visiblePlaylists.length,
                      totalMinutes: totalMinutes,
                      isScanning: library.isScanning,
                      scanProgress: library.scanProgress,
                      onPlayAll: playableSongs.isEmpty
                          ? null
                          : () => context
                              .read<PlayerProvider>()
                              .playFromQueue(playableSongs, 0),
                      onShuffle: playableSongs.isEmpty
                          ? null
                          : () {
                              final shuffled =
                                  List<SongModel>.from(playableSongs)
                                    ..shuffle(Random());
                              context
                                  .read<PlayerProvider>()
                                  .playFromQueue(shuffled, 0);
                            },
                    ),
                  ),
                  LibraryFilters(
                    source: _source,
                    content: _content,
                    isGrid: _isGridView,
                    sortLabel: _sortLabel(library.sortField),
                    ascending: library.sortAscending,
                    onSourceChanged: (value) => setState(() => _source = value),
                    onContentChanged: (value) =>
                        setState(() => _content = value),
                    onToggleGrid: () =>
                        setState(() => _isGridView = !_isGridView),
                    onSort: () => _showSortMenu(context, library),
                  ),
                  if (library.error != null)
                    SliverToBoxAdapter(
                      child: _LibraryError(
                        message: library.error!,
                        onRetry: library.refresh,
                      ),
                    ),
                  ..._buildContent(
                    library: library,
                    songs: songs,
                    albums: albums,
                    artists: artists,
                    visiblePlaylists: visiblePlaylists,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _canQueue(SongModel song) {
    final path = song.filePath.toLowerCase();
    final isRemote = path.startsWith('spotify://') ||
        path.startsWith('youtube://') ||
        path.startsWith('http://') ||
        path.startsWith('https://');
    return isRemote || File(song.filePath).existsSync();
  }

  List<Widget> _buildContent({
    required LibraryProvider library,
    required List<SongModel> songs,
    required List<AlbumModel> albums,
    required List<ArtistModel> artists,
    required List<PlaylistModel> visiblePlaylists,
  }) {
    return switch (_content) {
      LibraryContentFilter.songs => _songSlivers(songs),
      LibraryContentFilter.albums => _collectionSlivers(
          albums
              .map((album) => _albumEntry(library, album))
              .toList(growable: false),
          emptyTitle: 'Bu kaynakta albüm yok',
        ),
      LibraryContentFilter.artists => _collectionSlivers(
          artists
              .map((artist) => _artistEntry(library, artist))
              .toList(growable: false),
          emptyTitle: 'Bu kaynakta sanatçı yok',
        ),
      LibraryContentFilter.playlists => _collectionSlivers(
          _playlistEntries(library, visiblePlaylists),
          emptyTitle: 'Henüz çalma listen yok',
        ),
    };
  }

  List<Widget> _songSlivers(List<SongModel> songs) {
    if (songs.isEmpty) {
      return [
        LibraryEmptyState(
          title: 'Bu kaynakta parça yok',
          message:
              'Dosya veya klasör ekleyebilir, hesaplarını bağlayabilir ya da aygıtını yeniden tarayabilirsin.',
          onAdd: () => _showAddMenu(context, context.read<LibraryProvider>()),
        ),
      ];
    }

    if (_isGridView) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return LibraryCollectionCard(
                title: song.title,
                subtitle: song.artist,
                icon: Icons.music_note_rounded,
                artwork: song.albumArt,
                onTap: () => context.read<PlayerProvider>().playSong(song),
              );
            },
          ),
        ),
      ];
    }

    return [
      SliverList.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final player = context.watch<PlayerProvider>();
          return SongTile(
            key: ValueKey(song.id),
            song: song,
            isPlaying: player.currentSong?.id == song.id,
            onTap: () => player.playSong(song),
            showFileSize: true,
          );
        },
      ),
    ];
  }

  List<Widget> _collectionSlivers(
    List<_CollectionEntry> entries, {
    required String emptyTitle,
  }) {
    if (entries.isEmpty) {
      return [
        LibraryEmptyState(
          title: emptyTitle,
          message:
              'Farklı bir kaynak seçebilir veya kitaplığına yeni müzik ekleyebilirsin.',
          onAdd: () => _showAddMenu(context, context.read<LibraryProvider>()),
        ),
      ];
    }

    if (_isGridView) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final item = entries[index];
              return LibraryCollectionCard(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                artwork: item.artwork,
                onTap: item.onTap,
              );
            },
          ),
        ),
      ];
    }

    return [
      SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          return LibraryCollectionTile(
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            artwork: item.artwork,
            onTap: item.onTap,
          );
        },
      ),
    ];
  }

  List<AlbumModel> _matchingAlbums(
      LibraryProvider library, List<SongModel> songs) {
    if (_source == LibrarySourceFilter.all) return library.albums;
    final ids = songs.map((song) => song.id).toSet();
    return library.albums
        .where((album) => album.songIds.any(ids.contains))
        .toList(growable: false);
  }

  List<ArtistModel> _matchingArtists(
      LibraryProvider library, List<SongModel> songs) {
    if (_source == LibrarySourceFilter.all) return library.artists;
    final ids = songs.map((song) => song.id).toSet();
    return library.artists
        .where((artist) => artist.songIds.any(ids.contains))
        .toList(growable: false);
  }

  List<PlaylistModel> _matchingPlaylists(
      PlaylistProvider playlists, List<SongModel> songs) {
    if (_source == LibrarySourceFilter.all) return playlists.playlists;
    final ids = songs.map((song) => song.id).toSet();
    return playlists.playlists
        .where((playlist) => playlist.songIds.any(ids.contains))
        .toList(growable: false);
  }

  _CollectionEntry _albumEntry(LibraryProvider library, AlbumModel album) {
    final artwork = _artworkFor(library, album.songIds) ?? album.artwork;
    return _CollectionEntry(
      title: album.name,
      subtitle: '${album.artist} • ${album.songCount} parça',
      artwork: artwork,
      icon: Icons.album_rounded,
      onTap: () => _openPlaylist(
        PlaylistModel(
          id: 'album_${album.id}',
          name: album.name,
          songIds: album.songIds,
        ),
      ),
    );
  }

  _CollectionEntry _artistEntry(LibraryProvider library, ArtistModel artist) {
    return _CollectionEntry(
      title: artist.name,
      subtitle: '${artist.albumCount} albüm • ${artist.songCount} parça',
      artwork: artist.image ?? _artworkFor(library, artist.songIds),
      icon: Icons.person_rounded,
      onTap: () => _openPlaylist(
        PlaylistModel(
          id: 'artist_${artist.id}',
          name: artist.name,
          songIds: artist.songIds,
        ),
      ),
    );
  }

  List<_CollectionEntry> _playlistEntries(
      LibraryProvider library, List<PlaylistModel> playlists) {
    final matchingFavoriteIds = library.favorites
        .where(_source.matches)
        .map((song) => song.id)
        .toList(growable: false);
    final entries = <_CollectionEntry>[
      _CollectionEntry(
        title: 'Beğenilen Parçalar',
        subtitle: '${matchingFavoriteIds.length} parça',
        artwork: _artworkFor(library, matchingFavoriteIds),
        icon: Icons.favorite_rounded,
        onTap: () => _openPlaylist(
          PlaylistModel(
            id: 'favorites',
            name: 'Beğenilen Parçalar',
            songIds: matchingFavoriteIds,
          ),
        ),
      ),
    ];

    for (final playlist in playlists) {
      entries.add(_CollectionEntry(
        title: playlist.name,
        subtitle: '${playlist.songIds.length} parça',
        artwork: _artworkFor(library, playlist.songIds),
        icon: Icons.queue_music_rounded,
        onTap: () => _openPlaylist(playlist),
      ));
    }
    return entries;
  }

  Uint8List? _artworkFor(LibraryProvider library, Iterable<String> ids) {
    final songIds = ids.toSet();
    for (final song in library.songs) {
      if (songIds.contains(song.id) &&
          song.albumArt != null &&
          song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openPlaylist(PlaylistModel playlist) {
    _open(PlaylistDetailScreen(playlist: playlist));
  }

  Future<void> _showSearch(
      BuildContext pageContext, LibraryProvider library) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(pageContext).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = Theme.of(context).colorScheme;
          final query = controller.text.trim();
          final results =
              (query.isEmpty ? library.songs : library.search(query))
                  .where(_source.matches)
                  .toList(growable: false);
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SearchBar(
                    controller: controller,
                    autoFocus: true,
                    hintText: 'Parça, sanatçı veya albüm ara',
                    leading: Icon(Icons.search_rounded,
                        size: 18, color: colors.onSurfaceVariant),
                    trailing: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            controller.clear();
                            setSheetState(() {});
                          },
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: colors.onSurfaceVariant),
                        ),
                    ],
                    onChanged: (_) => setSheetState(() {}),
                    backgroundColor:
                        WidgetStatePropertyAll(colors.surfaceContainer),
                    side: WidgetStatePropertyAll(
                      BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    elevation: const WidgetStatePropertyAll(0),
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(color: colors.onSurface, fontSize: 13),
                    ),
                    hintStyle: WidgetStatePropertyAll(
                      TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('${results.length} sonuç',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 11)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  colors.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Text(_source.label,
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.4)),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text('Eşleşen müzik bulunamadı',
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13)))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final song = results[index];
                            return LibrarySongTile(
                              song: song,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                pageContext
                                    .read<PlayerProvider>()
                                    .playFromQueue(results, index);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _showSortMenu(
      BuildContext context, LibraryProvider library) async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Sırala',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.onSurface)),
              trailing: OutlinedButton.icon(
                onPressed: () {
                  library.toggleSortDirection();
                  Navigator.pop(sheetContext);
                },
                icon: Icon(
                    library.sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 14),
                label: Text(library.sortAscending ? 'Artan' : 'Azalan',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ),
            Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.4)),
            for (final field in SongSortField.values)
              RadioListTile<SongSortField>(
                value: field,
                groupValue: library.sortField,
                activeColor: colors.onSurface,
                title: Text(_sortLabel(field),
                    style: TextStyle(fontSize: 13, color: colors.onSurface)),
                onChanged: (value) {
                  if (value != null) library.setSortField(value);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortLabel(SongSortField field) => switch (field) {
        SongSortField.title => 'Başlık',
        SongSortField.artist => 'Sanatçı',
        SongSortField.album => 'Albüm',
        SongSortField.duration => 'Süre',
        SongSortField.dateAdded => 'Eklenme tarihi',
      };

  Future<void> _showAddMenu(
      BuildContext pageContext, LibraryProvider library) async {
    final colors = Theme.of(pageContext).colorScheme;
    final action = await showModalBottomSheet<_LibraryAddAction>(
      context: pageContext,
      showDragHandle: true,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Kitaplığına ekle',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              subtitle: Text('Yerel müzik veya bağlı bir kaynak seç',
                  style: TextStyle(
                      fontSize: 12, color: colors.onSurfaceVariant)),
            ),
            Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.4)),
            const _AddActionTile(
              icon: Icons.playlist_add_rounded,
              title: 'Çalma listesi oluştur',
              subtitle: 'Parçalarını kendi sıranla düzenle',
              action: _LibraryAddAction.playlist,
            ),
            const _AddActionTile(
              icon: Icons.audio_file_rounded,
              title: 'Dosya seç',
              subtitle: 'Bir veya daha fazla ses dosyası ekle',
              action: _LibraryAddAction.files,
            ),
            const _AddActionTile(
              icon: Icons.folder_copy_rounded,
              title: 'Klasör seç',
              subtitle: 'Bir müzik klasörünü topluca içe aktar',
              action: _LibraryAddAction.folder,
            ),
            const _AddActionTile(
              icon: Icons.manage_search_rounded,
              title: 'Aygıtı yeniden tara',
              subtitle: 'Yeni ve değişen müzik dosyalarını bul',
              action: _LibraryAddAction.scan,
            ),
            const _AddActionTile(
              icon: Icons.hub_rounded,
              title: 'Müzik kaynağı bağla',
              subtitle: 'Spotify, YouTube Music ve diğerleri',
              action: _LibraryAddAction.sources,
            ),
            const _AddActionTile(
              icon: Icons.video_file_rounded,
              title: 'Videodan Zil Sesi Oluştur',
              subtitle: 'Video dosyasından ses çıkarıp zil sesi yap',
              action: _LibraryAddAction.videoTools,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == _LibraryAddAction.playlist) {
      _open(const CreatePlaylistScreen());
      return;
    }
    if (action == _LibraryAddAction.sources) {
      _open(const SourceHubScreen());
      return;
    }
    if (action == _LibraryAddAction.videoTools) {
      _open(const VideoToolsScreen());
      return;
    }

    try {
      switch (action) {
        case _LibraryAddAction.files:
          await library.importFromFiles();
          break;
        case _LibraryAddAction.folder:
          await library.importFromDirectory();
          break;
        case _LibraryAddAction.scan:
          await library.scanMusic();
          break;
        case _LibraryAddAction.playlist:
        case _LibraryAddAction.sources:
        case _LibraryAddAction.videoTools:
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitaplık güncellendi')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem tamamlanamadı: $error')),
        );
      }
    }
  }
}

class _AddActionTile extends StatelessWidget {
  const _AddActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _LibraryAddAction action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 18, color: colors.onSurfaceVariant),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 16, color: colors.onSurfaceVariant),
      onTap: () => Navigator.pop(context, action),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded,
            size: 20, color: colors.onSurfaceVariant),
        title: Text('Kitaplık yüklenemedi',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        subtitle: Text(message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        trailing: IconButton(
          tooltip: 'Yeniden dene',
          onPressed: onRetry,
          icon: Icon(Icons.refresh_rounded,
              size: 18, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CollectionEntry {
  const _CollectionEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.artwork,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? artwork;
  final VoidCallback onTap;
}

enum _LibraryAddAction { playlist, files, folder, scan, sources, videoTools }
