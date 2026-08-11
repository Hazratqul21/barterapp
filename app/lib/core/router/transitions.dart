import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Motion between screens
// ─────────────────────────────────────────────────────────────────────────────
// Material's shared-axis transitions, chosen per kind of move, because the
// motion is what tells someone where they went.
//
// Before this the app used whatever `PageTransitionsTheme` matched the host
// platform. On the web that is decided by the browser's user agent, so the same
// site slid sideways in Safari and faded in Chrome — two different products
// depending on where it was opened.

/// Going deeper: a feed card into a listing, a listing into an offer.
///
/// Horizontal, because the new screen is a step forward along the same path
/// and "back" undoes it.
CustomTransitionPage<T> forwardPage<T>({
  required LocalKey key,
  required Widget child,
}) {
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

/// Rising over what is there: creating a listing, making an offer.
///
/// Vertical, so it reads as a task laid on top of the screen rather than a
/// place further along.
CustomTransitionPage<T> risingPage<T>({
  required LocalKey key,
  required Widget child,
}) {
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

/// Arriving from nowhere: splash into intro, intro into the app.
///
/// There is no spatial relationship between these, so nothing should slide.
CustomTransitionPage<T> fadePage<T>({
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

/// A push whose motion is a Hero, not the page.
///
/// The feed card and the listing page share the photograph, so the photograph
/// is the transition: it lifts out of the card and grows into the header. Put
/// a sliding page under that and the eye is given two conflicting motions at
/// once — the image travelling one way and the whole screen travelling
/// another — which is exactly what reads as "not smooth" even though every
/// individual animation is correct.
///
/// So the page underneath only fades. It gets out of the way and lets the
/// shared element do the work.
CustomTransitionPage<T> heroPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    // Matched to the Hero's own flight so the two finish together. A page that
    // finishes first leaves the image flying over a settled screen.
    transitionDuration: M3Motion.medium4,
    reverseTransitionDuration: M3Motion.medium3,
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: M3Motion.emphasizedDecelerate,
      ),
      child: child,
    ),
  );
}
