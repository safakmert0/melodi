import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:melodi/core/errors.dart';
import 'package:melodi/data/datasources/local/db_service.dart';
import 'package:melodi/data/datasources/local/secure_storage.dart';
import 'package:melodi/data/datasources/local/prefs.dart';
import 'package:melodi/data/datasources/native/melodi_core.dart';
import 'package:melodi/data/repositories/song_repository.dart';
import 'package:melodi/data/repositories/album_repository.dart';
import 'package:melodi/data/repositories/artist_repository.dart';
import 'package:melodi/data/repositories/playlist_repository.dart';
import 'package:melodi/data/repositories/download_repository.dart';
import 'package:melodi/data/repositories/source_repository.dart';
import 'package:melodi/domain/usecases/playback/get_stream_url.dart';
import 'package:melodi/domain/usecases/playback/play_song.dart';
import 'package:melodi/domain/usecases/playback/queue_manager.dart';
import 'package:melodi/domain/usecases/library/scan_local_files.dart';
import 'package:melodi/domain/usecases/library/import_from_navidrome.dart';
import 'package:melodi/domain/usecases/library/sync_playlists.dart';
import 'package:melodi/domain/usecases/search/search_all_sources.dart';
import 'package:melodi/domain/usecases/search/match_spotify_to_youtube.dart';
import 'package:melodi/domain/usecases/download/download_track.dart';
import 'package:melodi/domain/usecases/download/download_queue.dart';
import 'package:melodi/domain/usecases/download/ios_background_download.dart';

final melodiCoreProvider = Provider<MelodiCore>((ref) {
  return MelodiCore();
});

final dbServiceProvider = Provider<DbService>((ref) {
  return DbService();
});

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

final prefsProvider = Provider<Prefs>((ref) {
  return Prefs();
});

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(
    db: ref.watch(dbServiceProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository(
    db: ref.watch(dbServiceProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final artistRepositoryProvider = Provider<ArtistRepository>((ref) {
  return ArtistRepository(
    db: ref.watch(dbServiceProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(
    db: ref.watch(dbServiceProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(
    db: ref.watch(dbServiceProvider),
    melodiCore: ref.watch(melodiCoreProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SourceRepository(
    melodiCore: ref.watch(melodiCoreProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final getStreamUrlProvider = Provider<GetStreamUrl>((ref) {
  return GetStreamUrl(
    songRepository: ref.watch(songRepositoryProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final playSongProvider = Provider<PlaySong>((ref) {
  return PlaySong(
    getStreamUrl: ref.watch(getStreamUrlProvider),
    queueManager: ref.watch(queueManagerProvider),
  );
});

final queueManagerProvider = Provider<QueueManager>((ref) {
  return QueueManager();
});

final scanLocalFilesProvider = Provider<ScanLocalFiles>((ref) {
  return ScanLocalFiles(
    songRepository: ref.watch(songRepositoryProvider),
    albumRepository: ref.watch(albumRepositoryProvider),
    artistRepository: ref.watch(artistRepositoryProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final importFromNavidromeProvider = Provider<ImportFromNavidrome>((ref) {
  return ImportFromNavidrome(
    songRepository: ref.watch(songRepositoryProvider),
    albumRepository: ref.watch(albumRepositoryProvider),
    artistRepository: ref.watch(artistRepositoryProvider),
    playlistRepository: ref.watch(playlistRepositoryProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final syncPlaylistsProvider = Provider<SyncPlaylists>((ref) {
  return SyncPlaylists(
    playlistRepository: ref.watch(playlistRepositoryProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final searchAllSourcesProvider = Provider<SearchAllSources>((ref) {
  return SearchAllSources(
    melodiCore: ref.watch(melodiCoreProvider),
    songRepository: ref.watch(songRepositoryProvider),
  );
});

final matchSpotifyToYoutubeProvider = Provider<MatchSpotifyToYoutube>((ref) {
  return MatchSpotifyToYoutube(
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final downloadTrackProvider = Provider<DownloadTrack>((ref) {
  return DownloadTrack(
    downloadRepository: ref.watch(downloadRepositoryProvider),
    melodiCore: ref.watch(melodiCoreProvider),
    songRepository: ref.watch(songRepositoryProvider),
  );
});

final downloadQueueProvider = Provider<DownloadQueue>((ref) {
  return DownloadQueue(
    downloadRepository: ref.watch(downloadRepositoryProvider),
  );
});

final iosBackgroundDownloadProvider = Provider<IosBackgroundDownload>((ref) {
  return IosBackgroundDownload(
    downloadRepository: ref.watch(downloadRepositoryProvider),
    melodiCore: ref.watch(melodiCoreProvider),
  );
});

final isAppStoreBuildProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('APP_STORE');
});