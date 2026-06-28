import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants.dart';

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
    if (imageBytes != null) {
      return _buildFromBytes();
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildFromNetwork();
    }
    return _buildPlaceholder();
  }

  Widget _buildFromBytes() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        imageBytes!,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildFromNetwork() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        memCacheHeight: height != null ? (height! * 2).toInt() : null,
        placeholder: (_, __) => showShimmer ? _buildShimmer() : _buildPlaceholder(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: MelodiTheme.surfaceBright.withValues(alpha: 0.5),
      highlightColor: MelodiTheme.onSurfaceVariant.withValues(alpha: 0.1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: MelodiTheme.surfaceBright,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: (width ?? 48) * 0.5,
        color: MelodiTheme.onSurfaceVariant,
      ),
    );
  }
}
