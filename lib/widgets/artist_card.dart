import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/artist_model.dart';
import '../core/constants.dart';

class ArtistCard extends StatelessWidget {
  final ArtistModel artist;
  final VoidCallback? onTap;

  const ArtistCard({
    super.key,
    required this.artist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.darkCard,
              child: CircleAvatar(
                radius: 58,
                backgroundColor: AppTheme.darkCardHover,
                child: Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: AppTheme.textTertiary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            Text(
              '${artist.songCount} songs',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
    );
  }
}
