import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song_model.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/music_source.dart';
import '../image_with_fallback.dart';

Color musicSourceColor(MusicSourceType source) => switch (source) {
      MusicSourceType.youtube => const Color(0xFFFF453A),
      MusicSourceType.jiosaavn => const Color(0xFF2BC5B4),
      MusicSourceType.deezer => const Color(0xFFA970FF),
      MusicSourceType.navidrome => const Color(0xFF6C8CFF),
      MusicSourceType.hifi => const Color(0xFF1ED760),
    };

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
        size: 52,
        borderRadius: 13,
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
      trailing: IconButton.filledTonal(
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
    final sourceColor = musicSourceColor(track.source);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 52,
          height: 52,
          child: track.thumbnailUrl == null
              ? ColoredBox(
                  color: sourceColor.withValues(alpha: 0.15),
                  child: Icon(Icons.music_note_rounded, color: sourceColor),
                )
              : Image.network(
                  track.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: sourceColor.withValues(alpha: 0.15),
                    child: Icon(Icons.music_note_rounded, color: sourceColor),
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
              color: sourceColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              track.source.isPreviewCatalogue
                  ? '${track.sourceLabel} · katalog'
                  : track.sourceLabel,
              style: TextStyle(
                color: sourceColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
              icon: const Icon(Icons.download_rounded),
              onPressed: _download,
            ),
          if (_playing)
            const _BusyIndicator()
          else
            IconButton.filledTonal(
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
      for (var attempt = 0; attempt < 3; attempt++) {
        final url = await searchProvider.getStreamUrlWithFallback(
          widget.track,
          excludedUrls: attemptedUrls,
          forPlayback: true,
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
      final detail = lastError == null ? '' : ': $lastError';
      _message('Oynatma başarısız; erişilebilen kaynaklar denendi$detail',
          error: true);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final url = await context
          .read<SearchProvider>()
          .getStreamUrlWithFallback(widget.track);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _message('${widget.track.title} için indirilebilir kaynak bulunamadı',
            error: true);
        return;
      }
      final track = widget.track;
      context.read<DownloadProvider>().enqueueTrack(
            spotifyTrackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? track.sourceLabel,
            imageUrl: track.thumbnailUrl,
            sourceVideoId:
                track.source == MusicSourceType.youtube ? track.id : null,
            expectedDurationMs: track.duration.inMilliseconds,
            directUrl: url,
          );
      _message('${track.title} indirme kuyruğuna eklendi');
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

class SearchSourceFilters extends StatelessWidget {
  const SearchSourceFilters({
    super.key,
    required this.tracks,
    required this.selected,
    required this.onChanged,
  });

  final List<OnlineTrack> tracks;
  final MusicSourceType? selected;
  final ValueChanged<MusicSourceType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final counts = <MusicSourceType, int>{};
    for (final track in tracks) {
      counts.update(track.source, (value) => value + 1, ifAbsent: () => 1);
    }
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(context, null, 'Tümü', tracks.length),
          for (final entry in counts.entries)
            _chip(context, entry.key, _name(entry.key), entry.value),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    MusicSourceType? source,
    String label,
    int count,
  ) {
    final active = selected == source;
    final color = source == null
        ? Theme.of(context).colorScheme.primary
        : musicSourceColor(source);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: active,
        showCheckmark: false,
        avatar: source == null
            ? null
            : CircleAvatar(backgroundColor: color, radius: 4),
        label: Text('$label $count'),
        onSelected: (_) => onChanged(source),
      ),
    );
  }

  static String _name(MusicSourceType source) => switch (source) {
        MusicSourceType.youtube => 'YouTube',
        MusicSourceType.jiosaavn => 'JioSaavn',
        MusicSourceType.deezer => 'Deezer',
        MusicSourceType.navidrome => 'Navidrome',
        MusicSourceType.hifi => 'Hi-Fi',
      };
}
