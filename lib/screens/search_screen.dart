import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../models/song_model.dart';
import '../services/music_source.dart';
import '../services/youtube_service.dart';
import 'settings_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  MusicSourceType? _selectedSource;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                    Text('Melodi', style: MelodiTheme.heading(size: 20)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, color: MelodiTheme.onSurfaceVariant, size: 22),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(AppLocale.tr('search'), style: MelodiTheme.heading(size: 28)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: MelodiTheme.surfaceBright.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (query) {
                      setState(() => _isSearching = query.isNotEmpty);
                      if (query.isNotEmpty) context.read<SearchProvider>().search(query);
                    },
                    style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: AppLocale.tr('what_to_listen'),
                      hintStyle: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 15),
                      prefixIcon: const Icon(Icons.search_rounded, color: MelodiTheme.onSurfaceVariant, size: 22),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: MelodiTheme.onSurfaceVariant, size: 20),
                              onPressed: () { _searchController.clear(); setState(() => _isSearching = false); })
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
            if (_isSearching)
              Consumer<SearchProvider>(
                builder: (context, provider, _) {
                  return SliverList(delegate: SliverChildListDelegate([
                    // Local results header
                    if (provider.results.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(AppLocale.tr('local_results'), style: MelodiTheme.heading(size: 18)),
                      ),
                      ...provider.results.map((song) => _SearchResultTile(song: song)),
                    ],
                    // Online results header with source filter
                    if (provider.isSearchingOnline)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    if (!provider.isSearchingOnline && provider.onlineResults.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.language, color: MelodiTheme.primaryGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocale.tr('online_results'), style: MelodiTheme.heading(size: 18)),
                          ],
                        ),
                      ),
                      // Source filter chips
                      _SourceFilterChips(
                        tracks: provider.onlineResults,
                        selectedSource: _selectedSource,
                        onFilterChanged: (source) {
                          setState(() => _selectedSource = source);
                        },
                      ),
                      ...provider.onlineResults
                          .where((t) => _selectedSource == null || t.source == _selectedSource)
                          .map((track) => _OnlineResultTile(track: track)),
                    ],
                    // No results
                    if (!provider.isSearching && !provider.isSearchingOnline &&
                        provider.results.isEmpty && provider.onlineResults.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                provider.error != null
                                    ? Icons.cloud_off_rounded
                                    : Icons.search_off_rounded,
                                color: MelodiTheme.onSurfaceVariant,
                                size: 38,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                provider.error ?? AppLocale.tr('no_results'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: MelodiTheme.onSurfaceVariant),
                              ),
                              if (provider.error != null) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => provider.search(provider.query),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(AppLocale.tr('retry')),
                                ),
                              ],
                            ],
                          ),
                        )),
                      ),
                  ]));
                },
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(AppLocale.tr('artists'), style: MelodiTheme.heading(size: 20)),
                ),
              ),
              SliverToBoxAdapter(
                child: Consumer<LibraryProvider>(
                  builder: (context, library, _) {
                    final artists = library.artists.take(10).toList();
                    if (artists.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 16),
                        itemCount: artists.length,
                        itemBuilder: (context, index) {
                          final artist = artists[index];
                          return GestureDetector(
                            onTap: () {
                              final artistSongs = library.songs
                                  .where((s) => s.artist == artist.name)
                                  .toList();
                              if (artistSongs.isNotEmpty) {
                                context.read<PlayerProvider>().playFromQueue(artistSongs, 0);
                              }
                            },
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 90, height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                        colors: [MelodiTheme.primaryGreen.withOpacity(0.3), MelodiTheme.containerHigh],
                                      ),
                                    ),
                                    child: artist.image != null
                                        ? ClipOval(child: Image.memory(artist.image!, width: 90, height: 90, fit: BoxFit.cover))
                                        : const Icon(Icons.person_rounded, size: 40, color: MelodiTheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                      color: MelodiTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(AppLocale.tr('browse_all'), style: MelodiTheme.heading(size: 20)),
                ),
              ),
              SliverToBoxAdapter(child: _buildGenreGrid()),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    final genres = [
      ('Pop', const Color(0xFF8D67AB)),
      ('Rock', const Color(0xFFE8115B)),
      ('Hip-Hop', const Color(0xFFBC462B)),
      ('Electronic', const Color(0xFF2196F3)),
      ('Jazz', const Color(0xFF1E3264)),
      ('Classical', const Color(0xFF7358FF)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final g = genres[index];
          return GestureDetector(
            onTap: () {
              final library = context.read<LibraryProvider>();
              final genreSongs = library.songs
                  .where((s) => s.genre != null && s.genre!.toLowerCase().contains(g.$1.toLowerCase()))
                  .toList();
              if (genreSongs.isNotEmpty) {
                context.read<PlayerProvider>().playFromQueue(genreSongs, 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocale.tr('playing_genre').replaceAll('{genre}', g.$1)),
                    backgroundColor: MelodiTheme.primaryGreen,
                    duration: const Duration(seconds: 1),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocale.tr('no_genre_songs').replaceAll('{genre}', g.$1)),
                    backgroundColor: MelodiTheme.containerHigh,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: g.$2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8, bottom: -8,
                    child: Transform.rotate(
                      angle: 0.3,
                      child: Container(width: 56, height: 24,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(4))),
                    ),
                  ),
                  Positioned(
                    left: 14, bottom: 14,
                    child: Text(g.$1, style: const TextStyle(
                      fontFamily: AppConstants.fontFamily, color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SongModel song;
  const _SearchResultTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: MelodiTheme.containerHigh),
        child: song.albumArt != null
            ? ClipRRect(borderRadius: BorderRadius.circular(4),
                child: Image.memory(song.albumArt!, fit: BoxFit.cover, gaplessPlayback: true))
            : const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface, fontSize: 15)),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline_rounded, color: MelodiTheme.onSurfaceVariant),
        onPressed: () => context.read<PlayerProvider>().playSong(song)),
    );
  }
}

class _OnlineResultTile extends StatefulWidget {
  final OnlineTrack track;
  const _OnlineResultTile({required this.track});

  @override
  State<_OnlineResultTile> createState() => _OnlineResultTileState();
}

class _OnlineResultTileState extends State<_OnlineResultTile> {
  bool _isLoadingPlay = false;
  bool _isLoadingDownload = false;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Color _sourceColor(MusicSourceType source) {
    switch (source) {
      case MusicSourceType.youtube:
        return const Color(0xFFFF0000);
      case MusicSourceType.jiosaavn:
        return const Color(0xFF2BC5F4);
      case MusicSourceType.deezer:
        return const Color(0xFFA238FF);
      case MusicSourceType.lastfm:
        return const Color(0xFFD51007);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: MelodiTheme.containerHigh),
        child: track.thumbnailUrl != null
            ? ClipRRect(borderRadius: BorderRadius.circular(4),
                child: Image.network(track.thumbnailUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant)))
            : const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface, fontSize: 15)),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _sourceColor(track.source).withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(track.sourceLabel, style: TextStyle(
              color: _sourceColor(track.source), fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurfaceVariant, fontSize: 13)),
          ),
          if (track.duration.inSeconds > 0) ...[
            const SizedBox(width: 8),
            Text(_formatDuration(track.duration), style: TextStyle(color: MelodiTheme.textMuted, fontSize: 12)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoadingPlay)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.primaryGreen)),
            )
          else
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, color: MelodiTheme.primaryGreen),
              onPressed: () async {
                if (_isLoadingPlay) return;
                setState(() => _isLoadingPlay = true);
                try {
                  final searchProv = context.read<SearchProvider>();
                  // Try with fallback across all sources
                  final url = await searchProv.getStreamUrlWithFallback(track);
                  if (url != null && url.isNotEmpty && context.mounted) {
                    // For YouTube tracks, use video ID for reliable streaming
                    final filePath = track.source == MusicSourceType.youtube
                        ? 'youtube://${track.id}'
                        : url;
                    final song = SongModel(
                      id: track.id,
                      title: track.title,
                      artist: track.artist,
                      album: track.album ?? track.sourceLabel,
                      duration: track.duration,
                      filePath: url,
                      fileSize: 0,
                    );
                    await context.read<PlayerProvider>().playSong(song);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${track.title} oynatılamadı - tüm kaynaklar başarısız'),
                        backgroundColor: MelodiTheme.errorRed,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Oynatma hatası: $e'),
                        backgroundColor: MelodiTheme.errorRed,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoadingPlay = false);
                }
              },
            ),
          if (_isLoadingDownload)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MelodiTheme.onSurfaceVariant)),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded, color: MelodiTheme.onSurfaceVariant),
              onPressed: () async {
                if (_isLoadingDownload) return;
                setState(() => _isLoadingDownload = true);
                try {
                  final searchProv = context.read<SearchProvider>();
                  // Resolve URL first to verify availability
                  final url = await searchProv.getStreamUrlWithFallback(track);
                  if (url != null && url.isNotEmpty && context.mounted) {
                    context.read<DownloadProvider>().enqueueTrack(
                      spotifyTrackId: track.id,
                      title: track.title,
                      artist: track.artist,
                      album: track.album ?? track.sourceLabel,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${track.title} indiriliyor...'),
                        backgroundColor: MelodiTheme.primaryGreen,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${track.title} indirilemedi - kaynak bulunamadı'),
                        backgroundColor: MelodiTheme.errorRed,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('İndirme hatası: $e'),
                        backgroundColor: MelodiTheme.errorRed,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoadingDownload = false);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _SourceFilterChips extends StatelessWidget {
  final List<OnlineTrack> tracks;
  final MusicSourceType? selectedSource;
  final Function(MusicSourceType?) onFilterChanged;

  const _SourceFilterChips({
    required this.tracks,
    this.selectedSource,
    required this.onFilterChanged,
  });

  Color _sourceColor(MusicSourceType source) {
    switch (source) {
      case MusicSourceType.youtube:
        return const Color(0xFFFF0000);
      case MusicSourceType.jiosaavn:
        return const Color(0xFF2BC5F4);
      case MusicSourceType.deezer:
        return const Color(0xFFA238FF);
      case MusicSourceType.lastfm:
        return const Color(0xFFD51007);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceCounts = <MusicSourceType, int>{};
    for (final track in tracks) {
      sourceCounts[track.source] = (sourceCounts[track.source] ?? 0) + 1;
    }
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          GestureDetector(
            onTap: () => onFilterChanged(null),
            child: _buildChip('Tümü', tracks.length, MelodiTheme.primaryGreen, selectedSource == null),
          ),
          ...sourceCounts.entries.map((e) => GestureDetector(
            onTap: () => onFilterChanged(e.key),
            child: _buildChip(_sourceName(e.key), e.value, _sourceColor(e.key), selectedSource == e.key),
          )),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int count, Color color, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(
            color: isSelected ? color : color.withOpacity(0.8),
            fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('($count)', style: TextStyle(
            color: color.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }

  String _sourceName(MusicSourceType source) {
    switch (source) {
      case MusicSourceType.youtube:
        return 'YouTube';
      case MusicSourceType.jiosaavn:
        return 'JioSaavn';
      case MusicSourceType.deezer:
        return 'Deezer';
      case MusicSourceType.lastfm:
        return 'Last.fm';
    }
  }
}
