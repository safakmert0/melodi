import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import 'dart:async';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../services/podcast_service.dart';
import '../widgets/melodi_cache_image.dart';
import 'now_playing_screen.dart';

class PodcastDetailScreen extends StatefulWidget {
  final PodcastFeed feed;

  const PodcastDetailScreen({super.key, required this.feed});

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  final PodcastService _service = PodcastService.instance;
  final Set<String> _downloaded = {};
  final Set<String> _downloading = {};
  StreamSubscription<Duration>? _progressSub;
  DateTime _lastSaved = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDownloaded();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloaded() async {
    final set = <String>{};
    for (final ep in widget.feed.episodes) {
      if (await _service.isDownloaded(ep.id)) set.add(ep.id);
    }
    if (mounted) setState(() => _downloaded.addAll(set));
  }

  Future<void> _playEpisode(PodcastEpisode ep) async {
    final local = await _service.getLocalPath(ep.id);
    final filePath = local ?? ep.audioUrl;
    final song = SongModel(
      id: 'podcast:${ep.id}',
      title: ep.title,
      artist: widget.feed.title,
      album: widget.feed.title,
      duration: ep.duration,
      filePath: filePath,
      fileSize: 0,
    );

    final player = context.read<PlayerProvider>();
    await player.playSong(song);

    final pos = await _service.getProgress(ep.id);
    if (pos > Duration.zero &&
        ep.duration > Duration.zero &&
        pos < ep.duration) {
      await player.seek(pos);
    }

    _lastSaved = DateTime.now();
    _progressSub?.cancel();
    _progressSub = player.positionStream.listen((p) {
      final now = DateTime.now();
      if (now.difference(_lastSaved) > const Duration(seconds: 5)) {
        _lastSaved = now;
        _service.saveProgress(ep.id, widget.feed.id, p, false);
      }
    });

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
      );
    }
  }

  Future<void> _downloadEpisode(PodcastEpisode ep) async {
    if (_downloading.contains(ep.id)) return;
    setState(() => _downloading.add(ep.id));
    try {
      await _service.downloadEpisode(
        ep,
        podcastId: widget.feed.id,
        podcastTitle: widget.feed.title,
      );
      if (mounted) {
        setState(() => _downloaded.add(ep.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: ${ep.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(ep.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: MelodiTheme.containerLow,
            foregroundColor: MelodiTheme.onSurface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(feed.title,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (feed.imageUrl != null && feed.imageUrl!.isNotEmpty)
                    Image.network(
                      feed.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: MelodiTheme.containerLow),
                    )
                  else
                    Container(color: MelodiTheme.containerLow),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          MelodiTheme.background.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (feed.description.isNotEmpty)
                    Text(
                      feed.description,
                      style: TextStyle(
                        color: MelodiTheme.textMuted,
                        fontSize: 13,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${feed.episodes.length} episodes',
                    style: TextStyle(
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: feed.episodes.length,
            itemBuilder: (context, i) {
              final ep = feed.episodes[i];
              final isDown = _downloaded.contains(ep.id);
              final isDl = _downloading.contains(ep.id);
              return ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: MelodiCacheImage(
                    imageUrl: ep.imageUrl ?? feed.imageUrl,
                    width: 48,
                    height: 48,
                    borderRadius: 8,
                  ),
                ),
                title: Text(ep.title,
                    style: TextStyle(color: MelodiTheme.onSurface, fontSize: 14),
                    maxLines: 2),
                subtitle: Text(
                  [
                    if (ep.duration > Duration.zero)
                      '${ep.duration.inMinutes} min'
                    else
                      'Stream',
                    if (isDown) 'Downloaded',
                  ].join(' · '),
                  style: TextStyle(
                    color: isDown
                        ? MelodiTheme.primaryGreen
                        : MelodiTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Play',
                      icon: Icon(Icons.play_circle_fill_rounded,
                          color: MelodiTheme.primaryGreen, size: 30),
                      onPressed: () => _playEpisode(ep),
                    ),
                    if (isDl)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MelodiTheme.primaryGreen,
                        ),
                      )
                    else if (isDown)
                      IconButton(
                        tooltip: 'Re-download',
                        icon: Icon(Icons.check_circle_rounded,
                            color: MelodiTheme.primaryGreen, size: 22),
                        onPressed: () => _downloadEpisode(ep),
                      )
                    else
                      IconButton(
                        tooltip: 'Download',
                        icon: Icon(Icons.download_rounded,
                            color: MelodiTheme.onSurfaceVariant, size: 22),
                        onPressed: () => _downloadEpisode(ep),
                      ),
                  ],
                ),
                onTap: () => _playEpisode(ep),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
