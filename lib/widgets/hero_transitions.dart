import 'package:flutter/material.dart';

class MelodiHero {
  static Widget albumArt({required String tag, required Widget child, BorderRadius? borderRadius}) {
    return Hero(tag: tag, child: child);
  }

  static Widget playlistTitle({required String tag, required Widget child}) {
    return Hero(tag: tag, child: Material(color: Colors.transparent, child: child));
  }
}

class MelodiPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  MelodiPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}
