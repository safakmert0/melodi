import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../services/database_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  List<PlaylistModel> _playlists = [];
  bool _isLoading = false;

  List<PlaylistModel> get playlists => List.unmodifiable(_playlists);
  bool get isLoading => _isLoading;

  Future<void> loadPlaylists() async {
    _isLoading = true;
    notifyListeners();

    try {
      _playlists = await _db.getAllPlaylists();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<PlaylistModel> createPlaylist(String name, {String? description}) async {
    final playlist = PlaylistModel(
      id: _uuid.v4(),
      name: name,
      description: description,
      songIds: [],
    );

    await _db.insertPlaylist(playlist);
    _playlists.insert(0, playlist);
    notifyListeners();
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    await _db.deletePlaylist(id);
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final updated = _playlists[index].copyWith(name: newName);
    await _db.insertPlaylist(updated);
    _playlists[index] = updated;
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    if (playlist.songIds.contains(song.id)) return;

    final newSongIds = [...playlist.songIds, song.id];
    await _db.updatePlaylistSongs(playlistId, newSongIds);
    _playlists[index] = playlist.copyWith(songIds: newSongIds);
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    final newSongIds = playlist.songIds.where((id) => id != songId).toList();
    await _db.updatePlaylistSongs(playlistId, newSongIds);
    _playlists[index] = playlist.copyWith(songIds: newSongIds);
    notifyListeners();
  }

  Future<void> reorderPlaylist(
      String playlistId, int oldIndex, int newIndex) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    final songIds = List<String>.from(playlist.songIds);
    if (oldIndex < 0 || oldIndex >= songIds.length) return;
    if (newIndex < 0 || newIndex > songIds.length) return;

    final item = songIds.removeAt(oldIndex);
    songIds.insert(newIndex, item);

    await _db.updatePlaylistSongs(playlistId, songIds);
    _playlists[index] = playlist.copyWith(songIds: songIds);
    notifyListeners();
  }

  PlaylistModel? getPlaylistById(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<PlaylistModel> searchPlaylists(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    return _playlists
        .where((p) => p.name.toLowerCase().contains(lower))
        .toList();
  }
}
