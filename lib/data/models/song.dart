// Placeholder Song model - migration in progress
class Song {
  final String id;
  final String title;
  final String artist;
  const Song({required this.id, required this.title, required this.artist});
  factory Song.fromJson(Map<String, dynamic> j) => Song(id: j['id'] as String, title: j['title'] as String, artist: j['artist'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'artist': artist};
}
class Album { final String id; const Album({required this.id}); factory Album.fromJson(Map<String, dynamic> j) => Album(id: j['id'] as String); }
class Artist { final String id; const Artist({required this.id}); factory Artist.fromJson(Map<String, dynamic> j) => Artist(id: j['id'] as String); }
class Playlist { final String id; const Playlist({required this.id}); factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(id: j['id'] as String); }
class StreamUrl { final String url; const StreamUrl(this.url); }
class DownloadJob { final String id; const DownloadJob(this.id); }
class ExtensionManifest { final String id; const ExtensionManifest(this.id); }
class InstalledExtension { final String id; const InstalledExtension(this.id); }
