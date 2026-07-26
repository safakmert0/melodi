import '../models/song_model.dart';
import '../services/spotify_service.dart';

class SpotifyTrackMapper {
  SpotifyTrackMapper._();

  static String artistLabel(SpotifyTrackItem track) =>
      track.artists.isEmpty ? 'Unknown artist' : track.artists.join(', ');

  static SongModel toSong(SpotifyTrackItem track) {
    return SongModel(
      id: 'spotify:${track.id}',
      title: track.name,
      artist: artistLabel(track),
      album: track.albumName ?? '',
      duration: Duration(milliseconds: track.durationMs),
      filePath: 'spotify://${track.id}',
      fileSize: 0,
    );
  }

  static Map<String, String> toDownload(SpotifyTrackItem track) {
    return <String, String>{
      'id': track.id,
      'title': track.name,
      'artist': artistLabel(track),
      if (track.albumName != null && track.albumName!.isNotEmpty)
        'album': track.albumName!,
      if (track.albumImageUrl != null && track.albumImageUrl!.isNotEmpty)
        'imageUrl': track.albumImageUrl!,
    };
  }
}
