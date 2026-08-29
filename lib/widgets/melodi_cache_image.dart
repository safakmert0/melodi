import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MelodiCacheImage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final bool showShimmer;

  const MelodiCacheImage({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) return _buildFromBytes(context);
    if (imageUrl != null && imageUrl!.isNotEmpty) return _buildFromNetwork(context);
    return _buildPlaceholder(context);
  }

  Widget _buildFromBytes(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius.clamp(0, 12)),
      child: Image.memory(imageBytes!, width: width, height: height, fit: fit, gaplessPlayback: true, errorBuilder: (_, __, ___) => _buildPlaceholder(context)),
    );
  }

  Widget _buildFromNetwork(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius.clamp(0, 12)),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        memCacheHeight: height != null ? (height! * 2).toInt() : null,
        placeholder: (_, __) => showShimmer ? _buildShimmer(context) : _buildPlaceholder(context),
        errorWidget: (_, __, ___) => _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(width: width, height: height, color: scheme.surfaceContainerHighest);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(borderRadius.clamp(0, 12)), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      child: Icon(Icons.music_note_rounded, size: (width ?? 48) * 0.4, color: scheme.onSurfaceVariant),
    );
  }
}
