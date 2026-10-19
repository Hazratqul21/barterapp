import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart' show shouldReduceMotion;

/// Native transitions on phones; browser navigation does not slide a page.
Page<T> forwardPage<T>({required LocalKey key, required Widget child}) => kIsWeb
    ? NoTransitionPage<T>(key: key, child: child)
    : MaterialPage<T>(key: key, child: child);

Page<T> risingPage<T>({required LocalKey key, required Widget child}) => kIsWeb
    ? NoTransitionPage<T>(key: key, child: child)
    : MaterialPage<T>(key: key, child: child, fullscreenDialog: true);

Page<T> fadePage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: M3Motion.medium3,
    transitionsBuilder: (context, animation, secondary, child) {
      if (shouldReduceMotion(context)) return child;
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondary,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

Page<T> heroPage<T>({required LocalKey key, required Widget child}) {
  // Hero transitions must use CustomTransitionPage to prevent conflicting slide animations
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: M3Motion.medium4,
    reverseTransitionDuration: M3Motion.medium3,
    transitionsBuilder: (context, animation, secondary, child) =>
        shouldReduceMotion(context)
        ? child
        : FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: M3Motion.emphasizedDecelerate,
            ),
            child: child,
          ),
  );
}
