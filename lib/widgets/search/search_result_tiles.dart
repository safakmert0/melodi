import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song_model.dart';
import '../../theme/app_tokens.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/music_source.dart';
import '../image_with_fallback.dart';

class LocalSearchResultTile extends StatelessWidget {
  const LocalSearchResultTile({super.key, required this.song});
  final SongModel song;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ArtworkImage(
        imageBytes: song.albumArt,
        title: song.title,
        size: 48,
        borderRadius: 8,
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${song.artist} · Bu aygıt',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Oynat',
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: () => context.read<PlayerProvider>().playSong(song),
      ),
      onTap: () => context.read<PlayerProvider>().playSong(song),
    );
  }
}

class OnlineSearchResultTile extends StatefulWidget {
  const OnlineSearchResultTile({super.key, required this.track});
  final OnlineTrack track;

  @override
  State<OnlineSearchResultTile> createState() => _OnlineSearchResultTileState();
}

class _OnlineSearchResultTileState extends State<OnlineSearchResultTile> {
  bool _playing = false;
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: context.tokens.borderRadiusCover,
        child: SizedBox(
          width: 48,
          height: 48,
          child: track.thumbnailUrl == null
              ? ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.music_note_rounded,
                      color: cs.onSurfaceVariant, size: 22),
                )
              : Image.network(
                  track.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.music_note_rounded,
                        color: cs.onSurfaceVariant, size: 22),
                  ),
                ),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              track.sourceLabel,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (track.duration.inSeconds > 0) Text(_duration(track.duration)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_downloading)
            const _BusyIndicator()
          else
            IconButton(
              tooltip: 'İndir',
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: _download,
            ),
          if (_playing)
            const _BusyIndicator()
          else
            IconButton(
              tooltip: 'Oynat',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: _play,
            ),
        ],
      ),
      onTap: _play,
    );
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    final attemptedUrls = <String>{};
    final searchProvider = context.read<SearchProvider>();
    final playerProvider = context.read<PlayerProvider>();
    Object? lastError;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final url = await searchProvider.getStreamUrlWithFallback(
          widget.track,
          excludedUrls: attemptedUrls,
        );
        if (!mounted) return;
        if (url == null || url.isEmpty) break;
        attemptedUrls.add(url);

        final track = widget.track;
        final song = SongModel(
          id: track.id,
          title: track.title,
          artist: track.artist,
          album: track.album ?? track.sourceLabel,
          duration: track.duration,
          filePath: url,
          fileSize: 0,
        );
        try {
          await playerProvider.playSong(song);
          return;
        } catch (error) {
          lastError = error;
        }
      }

      if (!mounted) return;
      // Tek oynatici: tikla-oynasin. Dogrudan akis yoksa kisa hata ver.
      final detail = lastError == null ? '' : ': $lastError';
      _message('Çalınamadı$detail', error: true);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    final existing = context.read<LibraryProvider>().songs.where((song) {
      return _normalized(song.title) == _normalized(widget.track.title);
    }).toList();
    if (existing.isNotEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Müzik kitaplıkta mevcut'),
          content: Text(
            '"${widget.track.title}" adlı müzik kitaplığında zaten var. '
            'Yine de indirmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yine de indir'),
            ),
          ],
        ),
      );
      if (shouldContinue != true || !mounted) return;
    }
    setState(() => _downloading = true);
    try {
      final track = widget.track;
      final queued = context.read<DownloadProvider>().enqueueTrack(
            spotifyTrackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? track.sourceLabel,
            imageUrl: track.thumbnailUrl,
            sourceVideoId: track.id,
            expectedDurationMs: track.duration.inMilliseconds,
          );
      if (!mounted) return;
      if (queued) {
        _message('${track.title} indirme kuyruğuna eklendi');
      } else {
        _message('Bu parça zaten kuyrukta ya da indirilmiş');
      }
    } catch (error) {
      if (mounted) _message('İndirme hatası: $error', error: true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _message(String message, {bool error = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
    );
  }

  static String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _normalized(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f\u0400-\u04ff]+'), ' ')
      .trim();
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
