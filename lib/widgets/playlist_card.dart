import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('add_songs'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                onAddSongs?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
              title: Text(AppLocale.tr('rename_playlist'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: Text(AppLocale.tr('delete_playlist'),
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
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
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.card,
                    AppTheme.cardHover,
                    AppTheme.card,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.playlist_play_rounded,
                    size: 48,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${playlist.songCount} songs',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
    );
  }
}
