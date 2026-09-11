import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song_model.dart';
import '../../services/music_source.dart';
import '../../services/sources/youtube_source.dart';
import '../../theme/app_tokens.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
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
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final cs = Theme.of(context).colorScheme;
    final resolvingKey = context.read<SearchProvider>().resolvingTrackKey;
    final myKey = SearchProvider.trackKeyOf(track);
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
          ValueListenableBuilder<String?>(
            valueListenable: resolvingKey,
            builder: (context, resolving, _) {
              if (resolving == myKey) return const _BusyIndicator();
              return IconButton(
                tooltip: 'Oynat',
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: _play,
              );
            },
          ),
        ],
      ),
      onTap: _play,
    );
  }

  Future<void> _play() async {
    // Context okumaları async boşluk öncesi alınır.
    final searchProvider = context.read<SearchProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final key = SearchProvider.trackKeyOf(widget.track);
    // Aynı parçaya tekrar dokunma: zaten çözülüyor.
    if (searchProvider.resolvingTrackKey.value == key) return;
    // Yeni dokunuş öncekini hükümsüz kılar: eski spinner durur, eski iş
    // bitse bile çalmayı ele geçiremez.
    searchProvider.resolvingTrackKey.value = key;
    final attemptedUrls = <String>{};
    Object? lastError;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (searchProvider.resolvingTrackKey.value != key) return;
        final url = await searchProvider.getStreamUrlWithFallback(
          widget.track,
          excludedUrls: attemptedUrls,
          // Hızlı çalma: Hi-Fi'da FLAC indirmeyi bekleme, YouTube'dan akıt.
          forPlayback: true,
        );
        if (!mounted) return;
        if (searchProvider.resolvingTrackKey.value != key) return;
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
      if (searchProvider.resolvingTrackKey.value != key) return;
      // Tek oynatici: tikla-oynasin. Dogrudan akis yoksa kisa hata ver.
      final detail = lastError == null ? '' : ': $lastError';
      _message('Çalınamadı$detail', error: true);
    } finally {
      if (searchProvider.resolvingTrackKey.value == key) {
        searchProvider.resolvingTrackKey.value = null;
      }
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
    // Context okumaları async boşluk öncesi alınır (use_build_context_synchronously).
    final searchProvider = context.read<SearchProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    setState(() => _downloading = true);
    try {
      final track = widget.track;
      // Hi-Fi: id Spotify URL'sidir, videoId değildir. Önce sunucuda FLAC
      // akış adresini çöz, doğrudan dosya indirme olarak kuyruğa ekle.
      // Kaliteli servis vermezse otomatik YouTube (yt-dlp) yedeğine düş.
      // İkisi paralel çözülür, ek bekleme olmaz.
      String? directUrl;
      String? sourceVideoId = track.id;
      String? fallbackVideoId;
      if (track.source == MusicSourceType.hifi) {
        sourceVideoId = null;
        final resolved = await Future.wait([
          searchProvider
              .getStreamUrl(track)
              .timeout(const Duration(minutes: 6))
              .then((v) => v ?? '')
              .catchError((_) => ''),
          YouTubeSource()
              .resolveVideoId(
                title: track.title,
                artist: track.artist,
                durationMs: track.duration.inMilliseconds,
              )
              .timeout(const Duration(seconds: 45))
              .then((v) => v ?? '')
              .catchError((_) => ''),
        ]);
        directUrl = resolved[0].isEmpty ? null : resolved[0];
        fallbackVideoId = resolved[1].isEmpty ? null : resolved[1];
        if (directUrl == null) {
          // FLAC yok: YouTube yedeği zorunlu.
          if (fallbackVideoId == null || fallbackVideoId.isEmpty) {
            if (mounted) {
              _message('Hi-Fi akışı alınamadı, sonra tekrar dene',
                  error: true);
            }
            return;
          }
          sourceVideoId = fallbackVideoId;
        }
      }
      final queued = downloadProvider.enqueueTrack(
            spotifyTrackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? track.sourceLabel,
            imageUrl: track.thumbnailUrl,
            sourceVideoId: sourceVideoId,
            directUrl: directUrl,
            fallbackVideoId: fallbackVideoId,
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
