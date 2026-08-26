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
              stretch: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 64,
              expandedHeight: 146,
              backgroundColor:
                  theme.scaffoldBackgroundColor .withOpacity(0.94),
              surfaceTintColor: Colors.transparent,
              title: Text(
                'MELODI SEARCH',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 78, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keşfet.', style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 3),
                      Text(
                        'Aygıtında ve tüm kaynaklarda tek arama.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Müzik kaynakları',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SourceHubScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.hub_rounded),
                ),
                const SizedBox(width: 12),
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
          theme.colorScheme.surfaceContainerHighest .withOpacity(0.72),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: theme.colorScheme.onSurface .withOpacity(0.07),
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          Text(
            '$count sonuç',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Son aramalar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
    final artists = library.artists.take(12).toList();
    if (artists.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sanatçılarından başla',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return SizedBox(
                  width: 88,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(44),
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
                        CircleAvatar(
                          radius: 42,
                          foregroundImage: artist.image == null
                              ? null
                              : MemoryImage(artist.image!),
                          child: const Icon(Icons.person_rounded, size: 34),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
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
    final genres = library.genres.take(8).toList();
    if (genres.isEmpty) return const SizedBox.shrink();
    const colors = [
      Color(0xFF8D67AB),
      Color(0xFFE8115B),
      Color(0xFF1E3264),
      Color(0xFF148A68),
      Color(0xFFBC462B),
      Color(0xFF7358FF),
      Color(0xFF477D95),
      Color(0xFFB06239),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Türlere göz at',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
            ),
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  final songs = library.songs
                      .where((song) => genre.songIds.contains(song.id))
                      .toList();
                  if (songs.isNotEmpty) {
                    context.read<PlayerProvider>().playFromQueue(songs, 0);
                  }
                },
                child: Ink(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        genre.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${genre.songCount} şarkı',
                        style: TextStyle(
                          color: Colors.white .withOpacity(0.72),
                          fontSize: 11,
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
