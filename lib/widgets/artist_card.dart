import 'package:flutter/material.dart';
import '../models/artist_model.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                image: artist.image != null
                    ? DecorationImage(image: MemoryImage(artist.image!), fit: BoxFit.cover)
                    : null,
              ),
              child: artist.image == null
                  ? Icon(Icons.person_rounded, size: 36, color: scheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
            Text(
              '${artist.songCount} songs',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
