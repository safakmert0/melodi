import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/connection_provider.dart';
import '../models/song_model.dart';
import '../widgets/equalizer_sheet.dart';
import 'settings_screen.dart';
import 'playlist_detail_screen.dart';
import 'mixes_screen.dart';
import 'album_discovery_screen.dart';
import 'downloads_screen.dart';
import 'library_health_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleNotifier>();
    return Consumer3<LibraryProvider, PlaylistProvider, ConnectionProvider>(
      builder: (context, library, playlistProvider, conn, _) {
        return RefreshIndicator(
          onRefresh: () async => await library.loadAll(),
          color: MelodiTheme.primaryGreen,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MelodiTheme.containerHigh,
                          ),
                          child: const Icon(Icons.person, size: 20, color: MelodiTheme.onSurfaceVariant),
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
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(
                    _timeGreeting(),
                    style: MelodiTheme.heading(size: 26),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: library.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: CircularProgressIndicator(color: MelodiTheme.primaryGreen, strokeWidth: 2),
                        ),
                      )
                    : library.songs.isEmpty
                        ? _buildEmptyState(context)
                        : _buildQuickPicks(context, library),
              ),
              if (library.songs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildTopMixes(context),
                ),
              if (library.songs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildMadeForYou(context),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPicks(BuildContext context, LibraryProvider library) {
    final picks = library.recent.take(6).toList();
    if (picks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.2,
        ),
        itemCount: picks.length,
        itemBuilder: (context, index) {
          final song = picks[index];
          return GestureDetector(
            onTap: () => context.read<PlayerProvider>().playSong(song),
            child: Container(
              decoration: BoxDecoration(
                color: MelodiTheme.containerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    child: song.albumArt != null
                        ? Image.memory(song.albumArt!, width: 56, height: 56, fit: BoxFit.cover, gaplessPlayback: true)
                        : Container(width: 56, height: 56, color: MelodiTheme.containerHigh,
                            child: const Icon(Icons.music_note_rounded, size: 20, color: MelodiTheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopMixes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Top Mixes', style: MelodiTheme.heading(size: 20)),
              Text('SEE ALL', style: MelodiTheme.label(color: MelodiTheme.primaryGreen, letterSpacing: 0.08)),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: 4,
            itemBuilder: (context, index) {
              final mixes = [
                ('Daily Mix 1', 'The Weeknd, Daft Punk, Arctic Monkeys and more'),
                ('Chill Mix', 'Lofi Girl, Tycho, Bonobo and more'),
                ('Focus Mix', 'Brian Eno, Nils Frahm, Ólafur Arnalds and more'),
                ('Workout Mix', 'Dua Lipa, Doja Cat, Megan Thee Stallion and more'),
              ];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MelodiTheme.primaryGreen.withValues(alpha: 0.3 + index * 0.1),
                            MelodiTheme.containerHigh,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Text(
                              mixes[index].$1.toUpperCase(),
                              style: TextStyle(
                                fontFamily: AppConstants.fontFamily,
                                color: MelodiTheme.primaryGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mixes[index].$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        color: MelodiTheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMadeForYou(BuildContext context) {
    final items = [
      (Icons.favorite_rounded, 'Discover Weekly', 'Your weekly mixtape of fresh music. Enjoy.'),
      (Icons.circle_notifications_rounded, 'Release Radar', 'Catch all the latest music from artists you follow.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('Made For You', style: MelodiTheme.heading(size: 20)),
        ),
        ...items.map((item) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MelodiTheme.containerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.$1, color: MelodiTheme.primaryGreen, size: 24),
          ),
          title: Text(item.$2, style: const TextStyle(
            fontFamily: AppConstants.fontFamily, color: MelodiTheme.onSurface,
            fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: Text(item.$3, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: AppConstants.fontFamily,
              color: MelodiTheme.onSurfaceVariant, fontSize: 13, height: 1.3)),
          trailing: const Icon(Icons.chevron_right_rounded, color: MelodiTheme.onSurfaceVariant),
        )),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note_rounded, size: 80, color: MelodiTheme.textMuted),
            const SizedBox(height: 24),
            Text(AppLocale.tr('your_music_awaits'), style: MelodiTheme.heading(size: 22)),
            const SizedBox(height: 8),
            Text(AppLocale.tr('import_songs_to_start'), style: const TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 15)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.library_music_rounded),
              label: Text(AppLocale.tr('import_music')),
              style: FilledButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: MelodiTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppLocale.tr('good_morning');
    if (hour < 18) return AppLocale.tr('good_afternoon');
    return AppLocale.tr('good_evening');
  }
}
