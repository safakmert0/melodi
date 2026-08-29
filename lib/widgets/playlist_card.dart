import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../core/constants.dart';

class PlaylistCard extends StatelessWidget {
  final PlaylistModel playlist;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSongs;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAddSongs,
  });

  void _showContextMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: scheme.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('add_songs'), style: TextStyle(color: scheme.onSurface, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                onAddSongs?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant, size: 20),
              title: Text(AppLocale.tr('rename_playlist'), style: TextStyle(color: scheme.onSurface, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error, size: 20),
              title: Text(AppLocale.tr('delete_playlist'), style: TextStyle(color: scheme.error, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_play_rounded, size: 36, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    '${playlist.songCount} songs',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
