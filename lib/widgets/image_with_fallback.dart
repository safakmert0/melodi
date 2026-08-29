import 'dart:typed_data';
import 'package:flutter/material.dart';

class ArtworkImage extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? title;
  final double size;
  final double borderRadius;
  final Widget? fallback;

  const ArtworkImage({
    super.key,
    this.imageBytes,
    this.title,
    this.size = 48,
    this.borderRadius = 8,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius.clamp(0, 12)),
        child: Image.memory(
          imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(context),
        ),
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    return fallback ?? MelodiArtworkFallback(size: size, borderRadius: borderRadius);
  }
}

class MelodiArtworkFallback extends StatelessWidget {
  const MelodiArtworkFallback({super.key, this.size, this.borderRadius = 8});
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dimension = size ?? double.infinity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius.clamp(0, 12)),
      child: Container(
        width: dimension,
        height: dimension,
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.music_note_rounded, size: size == null ? 28 : size! * 0.4, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class ArtworkBackground extends StatelessWidget {
  final Uint8List? imageBytes;
  final Widget child;
  const ArtworkBackground({super.key, this.imageBytes, required this.child});

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(imageBytes!, fit: BoxFit.cover, opacity: const AlwaysStoppedAnimation(0.12)),
          ColoredBox(color: scheme.surface.withValues(alpha: 0.6), child: child),
        ],
      );
    }
    return child;
  }
}
