import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart' show shouldReduceMotion;

/// One feel on every platform (design v3): the iOS push — a slide with the
/// edge swipe back — on iOS, Android and the web alike. It used to be iOS
/// there and a shared-axis fade elsewhere, so the same app moved differently
/// depending on the phone it was opened on.
Page<T> forwardPage<T>({required LocalKey key, required Widget child}) =>
    CupertinoPage<T>(key: key, child: child);

/// Screens that rise over the current one (create, offer): the iOS modal.
Page<T> risingPage<T>({required LocalKey key, required Widget child}) =>
    CupertinoPage<T>(key: key, child: child, fullscreenDialog: true);

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
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: M3Motion.emphasizedDecelerate,
          ),
          child: child,
        ),
  );
}
