import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/song_model.dart';
import '../theme/app_tokens.dart';
import '../providers/player_provider.dart';
import '../services/discover_service.dart';
import '../widgets/melodi_cache_image.dart';
import 'discover_playlist_screen.dart';

SongModel _toSong(DiscoverItem item) => SongModel(
      id: 'disc_${item.id}',
      title: item.title,
      artist: item.artist,
      album: item.album ?? item.title,
      duration: item.duration,
      filePath: 'online://',
      fileSize: 0,
    );

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.category});

  final DiscoverCategory category;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<DiscoverItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DiscoverService.fetch(widget.category);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _playAll(List<DiscoverItem> songs) {
    final player = context.read<PlayerProvider>();
    final list = songs.map(_toSong).toList();
    if (list.isEmpty) return;
    player.playFromQueue(list, 0);
  }

  @override
  Widget build(BuildContext context) {
    final isPlaylist = widget.category == DiscoverCategory.topluluk;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'Sonuç bulunamadı.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: _items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            if (!isPlaylist && _items.isNotEmpty)
                              FilledButton.icon(
                                onPressed: () => _playAll(
                                  _items.where((e) => e.type == DiscoverItemType.song).toList(),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Tümünü Çal'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: MelodiTheme.primaryGreen,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    final item = _items[index - 1];
                    return _DiscoverTile(
                      item: item,
                      isPlaylist: isPlaylist,
                      onTap: () {
                        if (isPlaylist && item.playlistId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DiscoverPlaylistScreen(
                                playlistId: item.playlistId!,
                                title: item.title,
                                thumbnailUrl: item.thumbnailUrl,
                              ),
                            ),
                          );
                        } else {
                          final player = context.read<PlayerProvider>();
                          player.playSong(_toSong(item));
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.item,
    required this.isPlaylist,
    required this.onTap,
  });

  final DiscoverItem item;
  final bool isPlaylist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: context.tokens.borderRadiusCover,
      child: InkWell(
        borderRadius: context.tokens.borderRadiusCover,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: context.tokens.borderRadiusThumb,
                child: MelodiCacheImage(
                  imageUrl: item.thumbnailUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (!isPlaylist && item.duration > Duration.zero)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _format(item.duration),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color.onSurfaceVariant,
                        ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                isPlaylist ? Icons.chevron_right_rounded : Icons.play_circle_outline_rounded,
                color: color.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
