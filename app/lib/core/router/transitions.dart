import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;

import '../theme/app_theme.dart';

bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

Page<T> forwardPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  if (_isApple) return CupertinoPage<T>(key: key, child: child);

  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: M3Motion.medium4,
    reverseTransitionDuration: M3Motion.medium2,
    transitionsBuilder: (context, animation, secondary, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

Page<T> risingPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  // Rising (bottom sheet style) can use fullscreenDialog on iOS for the native modal feel.
  if (_isApple) {
    return CupertinoPage<T>(key: key, child: child, fullscreenDialog: true);
  }

  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: M3Motion.medium4,
    reverseTransitionDuration: M3Motion.medium2,
    transitionsBuilder: (context, animation, secondary, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.vertical,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

Page<T> fadePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: M3Motion.medium3,
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondary,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

Page<T> heroPage<T>({
  required LocalKey key,
  required Widget child,
}) {
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
