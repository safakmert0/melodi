import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/constants.dart';

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
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return fallback ??
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.card,
                AppTheme.cardHover,
              ],
            ),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: size * 0.45,
            color: AppTheme.textSecondary,
          ),
        );
  }
}

class ArtworkBackground extends StatelessWidget {
  final Uint8List? imageBytes;
  final Widget child;

  const ArtworkBackground({
    super.key,
    this.imageBytes,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            imageBytes!,
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.3),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.background,
                ],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          child,
        ],
      );
    }
    return child;
  }
}
