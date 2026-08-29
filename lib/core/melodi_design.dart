import 'package:flutter/material.dart';

abstract final class MelodiSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class MelodiRadius {
  static const double control = 10;
  static const double card = 12;
  static const double panel = 12;
  static const double artwork = 8;
}

abstract final class MelodiMotion {
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);
  static const Curve expressive = Curves.easeOutCubic;
}

class MelodiPanel extends StatelessWidget {
  const MelodiPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MelodiSpacing.md),
    this.onTap,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: emphasized
          ? colors.surfaceContainerHigh
          : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(MelodiRadius.card),
      border: Border.all(
        color: colors.outlineVariant.withValues(alpha: 0.5),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MelodiRadius.card),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
