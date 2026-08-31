import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song_model.dart';
import '../../theme/app_tokens.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/extension_service.dart';
import '../../services/multi_source_search.dart';
import '../../services/music_source.dart';
import '../../services/sources/extension_source.dart';
import '../image_with_fallback.dart';

Color musicSourceColor(MusicSourceType source) => const Color(0xFF3A3A3C);

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
              track.source.isPreviewCatalogue
                  ? '${track.sourceLabel} · katalog'
                  : track.sourceLabel,
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
    final selection = await _showDownloadSourceSheet(context, widget.track);
    if (selection.choice == _DownloadChoice.cancelled) return;
    if (!mounted) return;
    setState(() => _downloading = true);
    try {
      String? url;
      if (selection.choice == _DownloadChoice.auto) {
        url = await context.read<SearchProvider>().getStreamUrlWithFallback(widget.track);
      } else {
        url = await _getStreamForSpecificSource(selection, widget.track);
        if (url == null || url.isEmpty) {
          _message('${_downloadSourceLabel(selection.choice, extensionName: selection.extensionName)} kaynağında bulunamadı, otomatik deneniyor...', error: false);
          url = await context.read<SearchProvider>().getStreamUrlWithFallback(widget.track);
        }
      }
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _message('${widget.track.title} için indirilebilir kaynak bulunamadı', error: true);
        return;
      }
      final track = widget.track;
      context.read<DownloadProvider>().enqueueTrack(
            spotifyTrackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? track.sourceLabel,
            imageUrl: track.thumbnailUrl,
            sourceVideoId: track.source == MusicSourceType.youtube ? track.id : null,
            expectedDurationMs: track.duration.inMilliseconds,
            directUrl: url,
          );
      final label = selection.choice == _DownloadChoice.auto ? 'otomatik' : _downloadSourceLabel(selection.choice, extensionName: selection.extensionName);
      _message('${track.title} indirme kuyruğuna eklendi ($label)');
    } catch (error) {
      if (mounted) _message('İndirme hatası: $error', error: true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<String?> _getStreamForSpecificSource(
      _DownloadSelection selection, OnlineTrack track) async {
    try {
      // Extension-specific: try that extension directly
      if (selection.extensionId != null && selection.extensionId!.isNotEmpty) {
        try {
          final extSources = MultiSourceSearch().allSourcesForUi.whereType<ExtensionMusicSource>().where((s) => s.id == selection.extensionId).toList();
          if (extSources.isNotEmpty) {
            final src = extSources.first;
            // If track already from that extension, try direct
            if (track.extensionId == selection.extensionId) {
              final direct = await src.getStreamUrl(track);
              if (direct != null) return direct;
            }
            final query = '${track.artist} - ${track.title}'.trim();
            final results = await src.search(query, limit: 5);
            if (results.isNotEmpty) {
              results.sort((a, b) {
                final da = (a.duration.inMilliseconds - track.duration.inMilliseconds).abs();
                final db = (b.duration.inMilliseconds - track.duration.inMilliseconds).abs();
                return da.compareTo(db);
              });
              for (final cand in results) {
                final url = await src.getStreamUrl(cand);
                if (url != null) return url;
              }
            }
          }
        } catch (_) {}
      }
      final type = _choiceToSourceType(selection.choice);
      if (type == null) return null;
      if (track.source == type && track.extensionId == selection.extensionId) {
        final direct = await MultiSourceSearch().getStreamUrl(track);
        if (direct != null) return direct;
      }
      final query = '${track.artist} - ${track.title}'.trim();
      final results = await MultiSourceSearch().searchAllSync(query, limitPerSource: 5);
      final candidates = results.where((t) => t.source == type && (selection.extensionId == null || t.extensionId == selection.extensionId)).toList();
      // Fallback to any of that type if extension-specific empty
      final filtered = candidates.isEmpty ? results.where((t) => t.source == type).toList() : candidates;
      if (filtered.isEmpty) return null;
      filtered.sort((a, b) {
        final da = (a.duration.inMilliseconds - track.duration.inMilliseconds).abs();
        final db = (b.duration.inMilliseconds - track.duration.inMilliseconds).abs();
        return da.compareTo(db);
      });
      for (final cand in filtered) {
        final url = await MultiSourceSearch().getStreamUrl(cand);
        if (url != null) return url;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<_DownloadSelection> _showDownloadSourceSheet(
      BuildContext context, OnlineTrack track) async {
    final installed = ExtensionService.instance.installed.where((e) => e.enabled).toList();
    final hasHifiExt = installed.any((e) => e.manifest.kind.name == 'hifi');
    final hasBackendExt = installed.any((e) => e.manifest.kind.name == 'backend');
    final result = await showModalBottomSheet<_DownloadSelection>(
          context: context,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            Widget tile(_DownloadChoice c, String title, String subtitle, IconData icon, Color color, {String? extensionId}) {
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => Navigator.of(ctx).pop(_DownloadSelection(c, extensionId: extensionId)),
              );
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Kaynak seç', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('"${track.title}" için hangi kaynaktan indirilsin?',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                    tile(_DownloadChoice.auto, 'Otomatik (önerilen)', 'En iyi eşleşme tüm kaynaklarda aranır', Icons.auto_awesome_rounded, cs.primary),
                    tile(_DownloadChoice.youtube, 'YouTube', hasBackendExt ? 'Eklenti ile · yt-dlp backend' : 'Açık kaynak · Piped/yt-dlp', Icons.smart_display_rounded, const Color(0xFFFF3B30)),
                    if (hasHifiExt)
                      for (final ext in installed.where((e) => e.manifest.kind.name == 'hifi').take(3))
                        tile(_DownloadChoice.hifi, 'Hi-Fi · ${ext.manifest.name}', '${ext.manifest.author} · ${ext.manifest.version} · Lossless', Icons.graphic_eq_rounded, const Color(0xFF1ED760), extensionId: ext.manifest.id),
                    if (!hasHifiExt) tile(_DownloadChoice.hifi, 'Hi-Fi', 'Lossless sunucu (eklenti gerekli)', Icons.graphic_eq_rounded, const Color(0xFF1ED760)),
                    tile(_DownloadChoice.jiosaavn, 'JioSaavn', '320kbps · Hindistan kataloğu', Icons.waves_rounded, const Color(0xFF2BC5B4)),
                    tile(_DownloadChoice.navidrome, 'Navidrome', 'Kendi sunucun', Icons.dns_rounded, const Color(0xFF6C8CFF)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
    return result ?? _DownloadSelection(_DownloadChoice.cancelled);
  }

  String _downloadSourceLabel(_DownloadChoice c, {String? extensionName}) {
    if (c == _DownloadChoice.hifi && extensionName != null && extensionName.isNotEmpty) return 'Hi-Fi · $extensionName';
    return switch (c) {
      _DownloadChoice.youtube => 'YouTube',
      _DownloadChoice.hifi => 'Hi-Fi',
      _DownloadChoice.jiosaavn => 'JioSaavn',
      _DownloadChoice.navidrome => 'Navidrome',
      _DownloadChoice.auto => 'Otomatik',
      _DownloadChoice.cancelled => 'İptal',
    };
  }

  MusicSourceType? _choiceToSourceType(_DownloadChoice c) => switch (c) {
        _DownloadChoice.youtube => MusicSourceType.youtube,
        _DownloadChoice.hifi => MusicSourceType.hifi,
        _DownloadChoice.jiosaavn => MusicSourceType.jiosaavn,
        _DownloadChoice.navidrome => MusicSourceType.navidrome,
        _ => null,
      };

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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: active,
        showCheckmark: false,
        label: Text('$label $count', style: const TextStyle(fontSize: 13)),
        side: BorderSide(color: cs.outlineVariant),
        selectedColor: cs.surfaceContainerHighest,
        backgroundColor: cs.surface,
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
        MusicSourceType.appleMusic => 'Apple Music',
        MusicSourceType.soundcloud => 'SoundCloud',
      };
}

enum _DownloadChoice { auto, youtube, hifi, jiosaavn, navidrome, cancelled }

class _DownloadSelection {
  const _DownloadSelection(this.choice, {this.extensionId, this.extensionName});
  final _DownloadChoice choice;
  final String? extensionId;
  final String? extensionName;
}
