import 'package:flutter/material.dart';
import 'animation_constants.dart';

class PageTransitions {

  static PageRoute<T> slideTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(
          tween.chain(CurveTween(curve: AnimationConstants.defaultCurve)),
        );
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: AnimationConstants.normalDuration,
    );
  }

  static PageRoute<T> fadeTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(
            CurveTween(curve: AnimationConstants.defaultCurve),
          ),
          child: child,
        );
      },
      transitionDuration: AnimationConstants.normalDuration,
    );
  }

  static PageRoute<T> scaleTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: animation.drive(
            CurveTween(curve: AnimationConstants.springCurve),
          ),
          child: child,
        );
      },
      transitionDuration: AnimationConstants.normalDuration,
    );
  }
}
