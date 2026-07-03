import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../models/playlist_model.dart';
import '../models/artist_model.dart';
import '../models/album_model.dart';
import 'playlist_detail_screen.dart';
import 'create_playlist_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isGridView = false;
  String _sortBy = 'Recently Played';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: MelodiTheme.containerHigh),
                      child: const Icon(Icons.person, size: 20, color: MelodiTheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(AppLocale.tr('library'), style: MelodiTheme.heading(size: 20)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: MelodiTheme.onSurfaceVariant, size: 24),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreatePlaylistScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: MelodiTheme.onSurfaceVariant, size: 22),
                    onPressed: () => _showSearchDialog(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.swap_vert_rounded, size: 18, color: MelodiTheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(_sortBy, style: const TextStyle(
                    fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant,
                    fontSize: 15, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _isGridView = !_isGridView),
                    child: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      size: 20, color: MelodiTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer2<PlaylistProvider, LibraryProvider>(
                builder: (context, playlistProvider, library, _) {
                  final items = _buildLibraryItems(playlistProvider, library);

                  if (_isGridView) {
                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.8),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _buildGridItem(context, items[index]),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildListItem(context, items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MelodiTheme.containerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: MelodiTheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: MelodiTheme.onSurface, fontFamily: AppConstants.fontFamily, fontSize: 17),
                  decoration: InputDecoration(
                    hintText: AppLocale.tr('search'),
                    hintStyle: TextStyle(color: MelodiTheme.onSurfaceVariant.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search_rounded, color: MelodiTheme.onSurfaceVariant),
                    filled: true,
                    fillColor: MelodiTheme.containerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: Builder(
                    builder: (_) {
                      final query = controller.text.toLowerCase();
                      final library = context.read<LibraryProvider>();
                      final playlistProvider = context.read<PlaylistProvider>();
                      final allItems = _buildLibraryItems(playlistProvider, library);
                      final filtered = query.isEmpty
                          ? allItems
                          : allItems.where((i) => i.title.toLowerCase().contains(query)).toList();
                      if (filtered.isEmpty) {
                        return Center(child: Text(AppLocale.tr('no_results'), style: const TextStyle(color: MelodiTheme.onSurfaceVariant)));
                      }
                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => ListTile(
                          leading: Icon(filtered[i].icon, color: MelodiTheme.primaryGreen, size: 22),
                          title: Text(filtered[i].title, style: const TextStyle(color: MelodiTheme.onSurface, fontSize: 16)),
                          subtitle: Text(filtered[i].subtitle, style: const TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _handleItemTap(context, filtered[i]);
                          },
                        ),
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
  }

  void _handleItemTap(BuildContext context, _LibraryItem item) {
    if (item.type == _LibraryItemType.playlist && item.playlist != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: item.playlist!)));
    } else if (item.type == _LibraryItemType.likedSongs) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlist: PlaylistModel(
            id: 'favorites',
            name: 'Liked Songs',
            songIds: context.read<LibraryProvider>().favorites.map((s) => s.id).toList(),
          ),
        ),
      ));
    } else if (item.type == _LibraryItemType.artist && item.artist != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlist: PlaylistModel(
            id: 'artist_${item.artist!.id}',
            name: item.artist!.name,
            songIds: item.artist!.songIds,
          ),
        ),
      ));
    } else if (item.type == _LibraryItemType.album && item.album != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlist: PlaylistModel(
            id: 'album_${item.album!.id}',
            name: item.album!.name,
            songIds: item.album!.songIds,
          ),
        ),
      ));
    }
  }

  List<_LibraryItem> _buildLibraryItems(PlaylistProvider pp, LibraryProvider lib) {
    final items = <_LibraryItem>[];

    items.add(_LibraryItem(
      title: 'Liked Songs',
      subtitle: 'Playlist • ${lib.favorites.length} songs',
      gradient: const LinearGradient(colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)]),
      icon: Icons.favorite_rounded,
      type: _LibraryItemType.likedSongs,
    ));

    for (final p in pp.playlists) {
      items.add(_LibraryItem(
        title: p.name,
        subtitle: 'Playlist • ${p.songIds.length} songs',
        icon: Icons.queue_music_rounded,
        type: _LibraryItemType.playlist,
        playlist: p,
      ));
    }

    for (final a in lib.artists) {
      items.add(_LibraryItem(
        title: a.name,
        subtitle: 'Artist • ${a.songCount} songs',
        icon: Icons.person_rounded,
        type: _LibraryItemType.artist,
        artist: a,
      ));
    }

    for (final a in lib.albums) {
      items.add(_LibraryItem(
        title: a.name,
        subtitle: 'Album • ${a.artist}',
        icon: Icons.album_rounded,
        type: _LibraryItemType.album,
        album: a,
      ));
    }

    return items;
  }

  Widget _buildListItem(BuildContext context, _LibraryItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: item.gradient,
          color: item.gradient == null ? MelodiTheme.containerHigh : null,
        ),
        child: item.gradient != null
            ? Icon(item.icon, color: Colors.white, size: 24)
            : Icon(item.icon, color: MelodiTheme.onSurfaceVariant, size: 24),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface,
          fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
      onTap: () => _handleItemTap(context, item),
    );
  }

  Widget _buildGridItem(BuildContext context, _LibraryItem item) {
    return GestureDetector(
      onTap: () => _handleItemTap(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: MelodiTheme.containerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: item.gradient,
                  color: item.gradient == null ? MelodiTheme.containerHigh : null,
                ),
                child: Center(
                  child: Icon(item.icon, size: 40,
                    color: item.gradient != null ? Colors.white : MelodiTheme.onSurfaceVariant),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface,
                      fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LibraryItemType { likedSongs, playlist, artist, album }

class _LibraryItem {
  final String title;
  final String subtitle;
  final Gradient? gradient;
  final IconData icon;
  final _LibraryItemType type;
  final PlaylistModel? playlist;
  final ArtistModel? artist;
  final AlbumModel? album;

  _LibraryItem({
    required this.title,
    required this.subtitle,
    this.gradient,
    required this.icon,
    required this.type,
    this.playlist,
    this.artist,
    this.album,
  });
}
