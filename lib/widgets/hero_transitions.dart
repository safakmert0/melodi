import 'package:flutter/material.dart';
import '../core/constants.dart';

class MelodiHero {
  static Widget albumArt({
    required String tag,
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = animation.value;
            final radius = BorderRadius.lerp(
              BorderRadius.circular(8),
              BorderRadius.circular(12),
              t,
            )!;

            return ClipRRect(
              borderRadius: radius,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: MelodiTheme.primaryGreen.withValues(alpha: t * 0.2),
                      blurRadius: t * 40,
                      spreadRadius: t * 10,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }

  static Widget playlistTitle({
    required String tag,
    required Widget child,
  }) {
    return Hero(
      tag: tag,
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}

class MelodiPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  MelodiPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutQuart));
            final fadeTween = Tween(begin: 0.0, end: 1.0);

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        );
}
