import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/localization.dart';
import '../theme/app_tokens.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/database_service.dart';
import '../services/discover_service.dart';
import '../widgets/melodi_cache_image.dart';
import 'playlist_detail_screen.dart';

SongModel _toSong(DiscoverItem item) => SongModel(
      id: 'disc_${item.id}',
      title: item.title,
      artist: item.artist,
      album: item.album ?? item.title,
      duration: item.duration,
      filePath: 'online://',
      fileSize: 0,
    );

class DiscoverPlaylistScreen extends StatefulWidget {
  const DiscoverPlaylistScreen({
    super.key,
    required this.playlistId,
    required this.title,
    this.thumbnailUrl,
  });

  final String playlistId;
  final String title;
  final String? thumbnailUrl;

  @override
  State<DiscoverPlaylistScreen> createState() => _DiscoverPlaylistScreenState();
}

class _DiscoverPlaylistScreenState extends State<DiscoverPlaylistScreen> {
  List<DiscoverItem> _items = [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DiscoverService.playlistTracks(widget.playlistId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final songs = _items.map(_toSong).toList();
      final playlistProvider = context.read<PlaylistProvider>();
      final playlist = await playlistProvider.createPlaylist(widget.title);
      await DatabaseService.instance.insertSongs(songs);
      await playlistProvider.addSongsToPlaylist(
          playlist.id, songs.map((s) => s.id).toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.tr('playlist_imported')),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: color.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: color.surface,
            foregroundColor: color.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.title,
                  style: const TextStyle(fontSize: 16)),
              background: Container(
                color: color.surfaceContainer,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: MelodiCacheImage(
                          imageUrl: widget.thumbnailUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: _loading || _items.isEmpty
                        ? null
                        : () {
                            final player = context.read<PlayerProvider>();
                            player.playFromQueue(
                                _items.map(_toSong).toList(), 0);
                          },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Tümünü Çal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: color.onSurface,
                      foregroundColor: color.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _importing || _loading ? null : _import,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(_importing ? 'İçe Aktarılıyor…' : 'İçe Aktar'),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_items.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text(
                    'Parça bulunamadı.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final player = context.read<PlayerProvider>();
                      final list = _items.map(_toSong).toList();
                      player.playFromQueue(list, index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: context.tokens.borderRadiusThumb,
                            child: MelodiCacheImage(
                              imageUrl: item.thumbnailUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: color.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.play_circle_outline_rounded,
                            color: color.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
