import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/search_provider.dart';
import '../services/music_source.dart';
import '../services/podcast_service.dart';
import '../widgets/search/search_result_tiles.dart';
import 'podcast_detail_screen.dart';
import 'source_hub_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  MusicSourceType? _selectedSource;

  bool get _hasQuery => _controller.text.trim().isNotEmpty;

  Future<void> _maybeOpenPodcast(String value) async {
    if (!PodcastService.isPodcastUrl(value)) return;
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final feed = await PodcastService.instance.resolveUrl(value);
      await PodcastService.instance.subscribe(feed);
      if (!mounted) return;
      navigator.pop();
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PodcastDetailScreen(feed: feed),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open podcast: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey('melodi-search-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 56,
              title: Text(
                'Ara',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Müzik kaynakları',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SourceHubScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.hub_rounded),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(child: _searchField()),
            if (_hasQuery)
              Consumer<SearchProvider>(builder: _searchResults)
            else
              _DiscoveryContent(
                onSearchSelected: (query) {
                  _controller.text = query;
                  _controller.selection = TextSelection.collapsed(
                    offset: query.length,
                  );
                  context.read<SearchProvider>().search(query);
                  setState(() => _selectedSource = null);
                },
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 176)),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: SearchBar(
        controller: _controller,
        focusNode: _focusNode,
        hintText: 'Ne dinlemek istiyorsun?',
        leading: const Icon(Icons.search_rounded),
        trailing: [
          if (_hasQuery)
            IconButton(
              tooltip: 'Temizle',
              onPressed: () {
                _controller.clear();
                context.read<SearchProvider>().clearResults();
                setState(() {
                  _selectedSource = null;
                });
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerLow,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (query) {
          setState(() => _selectedSource = null);
          context.read<SearchProvider>().search(query.trim());
        },
        onSubmitted: (query) {
          final value = query.trim();
          if (value.isNotEmpty) {
            context.read<SearchProvider>().addRecentSearch(value);
            _maybeOpenPodcast(value);
          }
        },
      ),
    );
  }

  Widget _searchResults(
    BuildContext context,
    SearchProvider provider,
    Widget? child,
  ) {
    final online = provider.onlineResults
        .where((track) =>
            _selectedSource == null || track.source == _selectedSource)
        .toList();
    final children = <Widget>[];

    if (provider.results.isNotEmpty) {
      children.add(
        _ResultHeader(
          title: 'Bu aygıtta',
          count: provider.results.length,
          icon: Icons.phone_iphone_rounded,
        ),
      );
      children.addAll(
        provider.results.map((song) => LocalSearchResultTile(song: song)),
      );
    }

    if (provider.onlineResults.isNotEmpty) {
      children.add(
        _ResultHeader(
          title: 'Diğer kaynaklarda',
          count: provider.onlineResults.length,
          icon: Icons.public_rounded,
        ),
      );
      children.add(
        SearchSourceFilters(
          tracks: provider.onlineResults,
          selected: _selectedSource,
          onChanged: (value) => setState(() => _selectedSource = value),
        ),
      );
      children.add(const SizedBox(height: 5));
      children.addAll(
        online.map((track) => OnlineSearchResultTile(track: track)),
      );
    }

    if (provider.isSearching || provider.isSearchingOnline) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (!provider.isSearching &&
        !provider.isSearchingOnline &&
        provider.results.isEmpty &&
        provider.onlineResults.isEmpty) {
      children.add(
        _NoResults(
          message:
              provider.error ?? 'Bu aramayla eşleşen bir sonuç bulunamadı.',
          canRetry: provider.error != null,
          onRetry: () => provider.search(provider.query),
        ),
      );
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.title,
    required this.count,
    required this.icon,
  });
  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          Text(
            '$count sonuç',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });
  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        children: [
          Icon(
            canRetry ? Icons.cloud_off_rounded : Icons.search_off_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (canRetry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveryContent extends StatelessWidget {
  const _DiscoveryContent({required this.onSearchSelected});

  final ValueChanged<String> onSearchSelected;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return SliverList.list(
          children: [
            if (context.watch<SearchProvider>().recentSearches.isNotEmpty)
              _RecentSearches(
                searches: context.watch<SearchProvider>().recentSearches,
                onSelected: onSearchSelected,
              ),
            _ArtistRail(library: library),
            _GenreGrid(library: library),
          ],
        );
      },
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.searches, required this.onSelected});
  final List<String> searches;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Son aramalar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: context.read<SearchProvider>().clearRecentSearches,
                child: const Text('Temizle'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: searches
                .take(8)
                .map((search) => InputChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(search),
                      onPressed: () => onSelected(search),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ArtistRail extends StatelessWidget {
  const _ArtistRail({required this.library});
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artists = library.artists.take(12).toList();
    if (artists.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sanatçılarından başla',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return SizedBox(
                  width: 72,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final songs = library.songs
                          .where((song) => song.artist == artist.name)
                          .toList();
                      if (songs.isNotEmpty) {
                        context.read<PlayerProvider>().playFromQueue(songs, 0);
                      }
                    },
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: artist.image == null
                                ? ColoredBox(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 28,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Image.memory(
                                    artist.image!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreGrid extends StatelessWidget {
  const _GenreGrid({required this.library});
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genres = library.genres.take(8).toList();
    if (genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Türlere göz at',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.9,
            ),
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final songs = library.songs
                      .where((song) => genre.songIds.contains(song.id))
                      .toList();
                  if (songs.isNotEmpty) {
                    context.read<PlayerProvider>().playFromQueue(songs, 0);
                  }
                },
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        genre.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${genre.songCount} şarkı',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
