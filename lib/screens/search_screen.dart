import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/youtube_provider.dart';
import '../models/song_model.dart';
import '../services/youtube_service.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showClear = false;
  bool _youtubeMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _performSearch(String query, bool youtubeMode) {
    final searchProvider = context.read<SearchProvider>();
    final youtubeProvider = context.read<YouTubeProvider>();
    if (youtubeMode) {
      youtubeProvider.search(query);
    } else {
      searchProvider.search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: false,
            onChanged: (value) {
              setState(() => _showClear = value.isNotEmpty);
              _performSearch(value, _youtubeMode);
            },
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: AppLocale.tr('what_to_listen'),
              hintStyle:
                  TextStyle(color: AppTheme.textTertiary, fontSize: 16),
              filled: true,
              fillColor: AppTheme.card,
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppTheme.textTertiary),
              suffixIcon: _showClear
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: AppTheme.textTertiary),
                      onPressed: () {
                        _searchController.clear();
                        context.read<SearchProvider>().clearResults();
                        context.read<YouTubeProvider>().clearResults();
                        setState(() => _showClear = false);
                        _searchFocus.unfocus();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        // Tab selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _TabButton(
                label: AppLocale.tr('songs'),
                isActive: !_youtubeMode,
                onTap: () {
                  if (_youtubeMode) {
                    setState(() => _youtubeMode = false);
                    if (_searchController.text.isNotEmpty) {
                      context.read<SearchProvider>().search(_searchController.text);
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: 'YouTube',
                isActive: _youtubeMode,
                onTap: () {
                  if (!_youtubeMode) {
                    setState(() => _youtubeMode = true);
                    if (_searchController.text.isNotEmpty) {
                      context.read<YouTubeProvider>().search(_searchController.text);
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Results
        Expanded(
          child: _youtubeMode ? _buildYouTubeResults() : _buildLocalResults(),
        ),
      ],
      ),
    );
  }

  Widget _buildLocalResults() {
    return Consumer3<SearchProvider, LibraryProvider, LocaleNotifier>(
      builder: (context, searchProvider, library, locale, _) {
        if (searchProvider.query.isEmpty) {
          return _buildBrowseSection(searchProvider);
        }
        if (searchProvider.isSearching) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          );
        }
        if (searchProvider.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  '${AppLocale.tr('no_results_for')} "${searchProvider.query}"',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: searchProvider.results.length,
          itemBuilder: (context, index) {
            final song = searchProvider.results[index];
            return SongTile(
              song: song,
              onTap: () {
                context
                    .read<PlayerProvider>()
                    .playFromQueue(searchProvider.results, index);
                searchProvider.addRecentSearch(searchProvider.query);
              },
              onFavorite: () =>
                  context.read<LibraryProvider>().toggleFavorite(song),
            );
          },
        );
      },
    );
  }

  Widget _buildYouTubeResults() {
    return Consumer<YouTubeProvider>(
      builder: (context, ytProvider, _) {
        if (ytProvider.query.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline_rounded,
                    size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  AppLocale.tr('youtube_search_hint'),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        if (ytProvider.isSearching) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          );
        }
        if (ytProvider.isDownloading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 16),
                Text(
                  ytProvider.downloadProgress ?? AppLocale.tr('loading_song'),
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }
        if (ytProvider.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  '${AppLocale.tr('no_results_for')} "${ytProvider.query}"',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: ytProvider.results.length,
          itemBuilder: (context, index) {
            final video = ytProvider.results[index];
            return _YouTubeResultTile(
              video: video,
              onTap: () async {
                final url = await ytProvider.getAudioUrl(video.id);
                if (url != null && context.mounted) {
                  final song = SongModel(
                    id: 'yt_${video.id}',
                    title: video.title,
                    artist: video.author,
                    album: 'YouTube',
                    duration: video.duration,
                    filePath: url,
                    fileSize: 0,
                  );
                  context.read<PlayerProvider>().playSong(song);
                }
              },
              onDownload: () async {
                final path = await ytProvider.downloadAudio(video.id, video.title);
                if (path != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${AppLocale.tr('download_complete')}: ${video.title}'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBrowseSection(SearchProvider searchProvider) {
    return Consumer<LocaleNotifier>(
      builder: (context, locale, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Recent searches
            if (searchProvider.recentSearches.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocale.tr('recent_searches'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: searchProvider.clearRecentSearches,
                        child: Text(
                          AppLocale.tr('clear'),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recent = searchProvider.recentSearches[index];
                    return ListTile(
                      leading: Icon(Icons.history_rounded,
                          color: AppTheme.textTertiary),
                      title: Text(recent,
                          style:
                              TextStyle(color: AppTheme.textPrimary)),
                      trailing: Icon(Icons.arrow_upward_rounded,
                          color: AppTheme.textTertiary, size: 16),
                      onTap: () {
                        _searchController.text = recent;
                        _performSearch(recent, _youtubeMode);
                        setState(() => _showClear = true);
                      },
                    );
                  },
                  childCount: searchProvider.recentSearches.length,
                ),
              ),
            ],
            // Browse all
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.tr('browse_all'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Pop', 'Rock', 'Jazz', 'Classical',
                        'Electronic', 'Hip Hop', 'R&B', 'Metal',
                        'Folk', 'Blues', 'Reggae', 'Country',
                      ].map((genre) {
                        return ActionChip(
                          label: Text(genre),
                          onPressed: () {
                            _searchController.text = genre;
                            _performSearch(genre, _youtubeMode);
                            setState(() => _showClear = true);
                          },
                          backgroundColor: AppTheme.card,
                          labelStyle: TextStyle(
                            color: AppTheme.textPrimary,
                          ),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _YouTubeResultTile extends StatelessWidget {
  final YouTubeVideo video;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const _YouTubeResultTile({
    required this.video,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr = video.duration.inHours > 0
        ? '${video.duration.inHours}:${(video.duration.inMinutes % 60).toString().padLeft(2, '0')}:${(video.duration.inSeconds % 60).toString().padLeft(2, '0')}'
        : '${video.duration.inMinutes}:${(video.duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: AppTheme.card,
          child: Icon(Icons.play_circle_outline, color: AppTheme.textTertiary),
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              video.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            ' · $durationStr',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.download_rounded, size: 20),
        color: AppTheme.textSecondary,
        onPressed: onDownload,
      ),
    );
  }
}
