import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<SearchProvider, LibraryProvider, LocaleNotifier>(
      builder: (context, searchProvider, library, locale, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: Text(
                AppLocale.tr('search'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              floating: true,
              pinned: false,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: false,
                  onChanged: (value) {
                    searchProvider.search(value);
                    setState(() => _showClear = value.isNotEmpty);
                  },
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: AppLocale.tr('what_to_listen'),
                    hintStyle:
                        const TextStyle(color: AppTheme.textTertiary, fontSize: 16),
                    filled: true,
                    fillColor: AppTheme.darkCard,
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textTertiary),
                    suffixIcon: _showClear
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: AppTheme.textTertiary),
                            onPressed: () {
                              _searchController.clear();
                              searchProvider.clearResults();
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
                          const BorderSide(color: AppTheme.primaryColor, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            if (searchProvider.query.isNotEmpty) ...[
              if (searchProvider.isSearching)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              else if (searchProvider.results.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          '${AppLocale.tr('no_results_for')} "${searchProvider.query}"',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                    childCount: searchProvider.results.length,
                  ),
                ),
            ] else ...[
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
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: searchProvider.clearRecentSearches,
                          child: Text(
                            AppLocale.tr('clear'),
                            style: const TextStyle(
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
                        leading: const Icon(Icons.history_rounded,
                            color: AppTheme.textTertiary),
                        title: Text(recent,
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
                        trailing: const Icon(Icons.arrow_upward_rounded,
                            color: AppTheme.textTertiary, size: 16),
                        onTap: () {
                          _searchController.text = recent;
                          searchProvider.search(recent);
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
                        style: const TextStyle(
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
                              searchProvider.search(genre);
                              setState(() => _showClear = true);
                            },
                            backgroundColor: AppTheme.darkCard,
                            labelStyle: const TextStyle(
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
          ],
        );
      },
    );
  }
}
