import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  AppLocale.tr('search'),
                  style: MelodiTheme.heading(size: 28),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  color: MelodiTheme.background,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: MelodiTheme.surfaceBright.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: (query) {
                            setState(() => _isSearching = query.isNotEmpty);
                            if (query.isNotEmpty) {
                              context.read<SearchProvider>().search(query);
                            }
                          },
                          style: const TextStyle(
                            fontFamily: AppConstants.fontFamily,
                            color: MelodiTheme.onSurface,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: AppLocale.tr('search_hint'),
                            hintStyle: const TextStyle(
                              fontFamily: AppConstants.fontFamily,
                              color: MelodiTheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, color: MelodiTheme.onSurfaceVariant),
                            suffixIcon: _isSearching
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: MelodiTheme.onSurfaceVariant),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _isSearching = false);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isSearching)
              Consumer<SearchProvider>(
                builder: (context, provider, _) {
                  if (provider.results.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(
                          AppLocale.tr('no_results'),
                          style: const TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 15),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = provider.results[index];
                        return _SearchResultTile(song: song);
                      },
                      childCount: provider.results.length,
                    ),
                  );
                },
              )
            else
              SliverToBoxAdapter(
                child: _buildGenreGrid(),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    final genres = [
      _GenreItem('pop', MelodiTheme.genreColors['pop']!),
      _GenreItem('rock', MelodiTheme.genreColors['rock']!),
      _GenreItem('hip_hop', MelodiTheme.genreColors['hip_hop']!),
      _GenreItem('jazz', MelodiTheme.genreColors['jazz']!),
      _GenreItem('electronic', MelodiTheme.genreColors['electronic']!),
      _GenreItem('classical', MelodiTheme.genreColors['classical']!),
      _GenreItem('rnb', MelodiTheme.genreColors['rnb']!),
      _GenreItem('indie', MelodiTheme.genreColors['indie']!),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          return _GenreCard(genre: genre);
        },
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _SearchBarDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _GenreItem {
  final String name;
  final Color color;

  const _GenreItem(this.name, this.color);
}

class _GenreCard extends StatelessWidget {
  final _GenreItem genre;

  const _GenreCard({required this.genre});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: genre.color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -8,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  width: 56,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: Text(
                AppLocale.tr(genre.name),
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: MelodiTheme.surfaceMid2,
        ),
        child: song.albumArt != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(song.albumArt!, fit: BoxFit.cover, gaplessPlayback: true),
              )
            : const Icon(Icons.music_note_rounded, color: MelodiTheme.onSurfaceVariant),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppConstants.fontFamily,
          color: MelodiTheme.onSurface,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppConstants.fontFamily,
          color: MelodiTheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline_rounded, color: MelodiTheme.onSurfaceVariant),
        onPressed: () => context.read<PlayerProvider>().playSong(song),
      ),
    );
  }
}
