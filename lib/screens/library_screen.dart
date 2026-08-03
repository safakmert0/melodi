import 'dart:math';
import 'dart:io';
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
            final sourceSongs =
                widget.favoritesOnly ? library.favorites : library.songs;
            final songs = sourceSongs.where(_source.matches).toList();
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
                  const SliverToBoxAdapter(child: SizedBox(height: 130)),
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
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
                gradient: item.gradient,
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
            gradient: item.gradient,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4D2CFF), Color(0xFF63E6BE)],
        ),
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
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
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            controller.clear();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text('${results.length} sonuç',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                      const Spacer(),
                      Text(_source.label,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: results.isEmpty
                      ? const Center(child: Text('Eşleşen müzik bulunamadı'))
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Sırala',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: TextButton.icon(
                onPressed: () {
                  library.toggleSortDirection();
                  Navigator.pop(sheetContext);
                },
                icon: Icon(library.sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
                label: Text(library.sortAscending ? 'Artan' : 'Azalan'),
              ),
            ),
            for (final field in SongSortField.values)
              RadioListTile<SongSortField>(
                value: field,
                groupValue: library.sortField,
                title: Text(_sortLabel(field)),
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
    final action = await showModalBottomSheet<_LibraryAddAction>(
      context: pageContext,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              title: Text('Kitaplığına ekle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              subtitle: Text('Yerel müzik veya bağlı bir kaynak seç'),
            ),
            _AddActionTile(
              icon: Icons.playlist_add_rounded,
              title: 'Çalma listesi oluştur',
              subtitle: 'Parçalarını kendi sıranla düzenle',
              action: _LibraryAddAction.playlist,
            ),
            _AddActionTile(
              icon: Icons.audio_file_rounded,
              title: 'Dosya seç',
              subtitle: 'Bir veya daha fazla ses dosyası ekle',
              action: _LibraryAddAction.files,
            ),
            _AddActionTile(
              icon: Icons.folder_copy_rounded,
              title: 'Klasör seç',
              subtitle: 'Bir müzik klasörünü topluca içe aktar',
              action: _LibraryAddAction.folder,
            ),
            _AddActionTile(
              icon: Icons.manage_search_rounded,
              title: 'Aygıtı yeniden tara',
              subtitle: 'Yeni ve değişen müzik dosyalarını bul',
              action: _LibraryAddAction.scan,
            ),
            _AddActionTile(
              icon: Icons.hub_rounded,
              title: 'Müzik kaynağı bağla',
              subtitle: 'Spotify, YouTube Music ve diğerleri',
              action: _LibraryAddAction.sources,
            ),
            SizedBox(height: 8),
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
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Kitaplık yüklenemedi'),
        subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'Yeniden dene',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
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
    this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? artwork;
  final Gradient? gradient;
  final VoidCallback onTap;
}

enum _LibraryAddAction { playlist, files, folder, scan, sources }
