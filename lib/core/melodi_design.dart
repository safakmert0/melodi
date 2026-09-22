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

/// Premium golgeler: acik temada derinlik, koyuda hafif isima.
abstract final class MelodiShadows {
  static List<BoxShadow> card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0xFF0F172A).withValues(alpha: 0.08),
        blurRadius: dark ? 16 : 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> artwork(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.5)
            : const Color(0xFF0F172A).withValues(alpha: 0.22),
        blurRadius: dark ? 28 : 40,
        offset: const Offset(0, 16),
      ),
    ];
  }
}

/// Bolum basligi: kalin baslik + soluk alt yazi + sagda aksiyon.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
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
