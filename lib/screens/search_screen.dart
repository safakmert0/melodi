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
  bool _isSearching = false;

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
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: MelodiTheme.containerHigh),
                      child: const Icon(Icons.person, size: 20, color: MelodiTheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 12),
                    Text('Melodi', style: MelodiTheme.heading(size: 20)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, color: MelodiTheme.onSurfaceVariant, size: 22),
                      onPressed: () {},
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
                padding: const.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: MelodiTheme.surfaceBright.withValues(alpha: 0.15),
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
                      hintText: 'Songs, Artists, or Albums',
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
                  if (provider.results.isEmpty) {
                    return const SliverFillRemaining(child: Center(
                      child: Text('No results found', style: TextStyle(color: MelodiTheme.onSurfaceVariant))));
                  }
                  return SliverList(delegate: SliverChildBuilderDelegate(
                    (context, i) => _SearchResultTile(song: provider.results[i]),
                    childCount: provider.results.length));
                },
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trending Artists', style: MelodiTheme.heading(size: 20)),
                      Text('See all', style: MelodiTheme.label(color: MelodiTheme.primaryGreen)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final artists = ['Luna Ray', 'Drove', 'Mira Sol', 'Soma Silence', 'Neon Architect'];
                      return Container(
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
                                  colors: [MelodiTheme.containerHigh, MelodiTheme.containerLow],
                                ),
                              ),
                              child: const Icon(Icons.person_rounded, size: 40, color: MelodiTheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Text(artists[index], maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: AppConstants.fontFamily,
                                color: MelodiTheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text('Browse All', style: MelodiTheme.heading(size: 20)),
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
      ('Electronic', const Color(0xFF1DB954)),
      ('Podcast', const Color(0xFF7358FF)),
      ('Chill', const Color(0xFF006450)),
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
          return Container(
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
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4))),
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
