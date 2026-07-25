import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/home/home_content.dart';
import '../widgets/home/home_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<LibraryProvider, PlaylistProvider, ConnectionProvider>(
      builder: (context, library, playlists, connection, _) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              library.loadAll(),
              playlists.loadPlaylists(),
              connection.refreshStatus(),
            ]);
          },
          child: CustomScrollView(
            key: const PageStorageKey('melodi-home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              HomeHeader(connection: connection),
              if (library.error != null)
                HomeLibraryError(
                  message: library.error!,
                  onRetry: library.loadAll,
                ),
              if (library.isLoading && library.songs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (library.songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: HomeEmptyLibrary(library: library),
                )
              else
                HomeContent(library: library, playlists: playlists),
            ],
          ),
        );
      },
    );
  }
}
