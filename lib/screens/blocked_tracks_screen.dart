import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/blocklist_service.dart';

class BlockedTracksScreen extends StatefulWidget {
  const BlockedTracksScreen({super.key});

  @override
  State<BlockedTracksScreen> createState() => _BlockedTracksScreenState();
}

class _BlockedTracksScreenState extends State<BlockedTracksScreen> {
  final _blocklist = BlocklistService.instance;
  final _searchController = TextEditingController();
  List<BlockedTrack> _tracks = [];
  List<BlockedTrack> _filteredTracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() => _loading = true);
    final tracks = await _blocklist.getBlockedTracks();
    if (mounted) {
      setState(() {
        _tracks = tracks;
        _filteredTracks = tracks;
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = _tracks;
      } else {
        _filteredTracks = _tracks.where((t) =>
          t.title.toLowerCase().contains(query) ||
          t.artist.toLowerCase().contains(query)
        ).toList();
      }
    });
  }

  Future<void> _unblockTrack(String trackId) async {
    await _blocklist.unblockTrack(trackId);
    _loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('blocklist')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocale.tr('search'),
                  hintStyle: TextStyle(color: MelodiTheme.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: MelodiTheme.textMuted, size: 20),
                  filled: true,
                  fillColor: MelodiTheme.containerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(color: MelodiTheme.onSurface, fontSize: 14),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTracks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        itemCount: _filteredTracks.length,
                        itemBuilder: (context, index) {
                          final track = _filteredTracks[index];
                          return _buildTrackTile(track);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.block_rounded,
            size: 64,
            color: MelodiTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery
                ? '${AppLocale.tr('no_results_for')} "${_searchController.text.trim()}"'
                : AppLocale.tr('no_blocked_tracks'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(BlockedTrack track) {
    return Dismissible(
      key: ValueKey(track.trackId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: MelodiTheme.errorRed,
        child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _unblockTrack(track.trackId),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: MelodiTheme.containerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.music_note_rounded, color: MelodiTheme.textMuted, size: 22),
        ),
        title: Text(
          track.title,
          style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artist,
          style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          height: 32,
          child: TextButton(
            onPressed: () => _unblockTrack(track.trackId),
            style: TextButton.styleFrom(
              foregroundColor: MelodiTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: MelodiTheme.primaryGreen.withOpacity(0.4)),
              ),
            ),
            child: Text(
              AppLocale.tr('unblock'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
