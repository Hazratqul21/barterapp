import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../widgets/common.dart' show shouldReduceMotion;

// ─────────────────────────────────────────────────────────────────────────────
// Motion v2 — springs, not stopwatches
// ─────────────────────────────────────────────────────────────────────────────
// A fixed-duration ease is a recording played back: it ignores where the thing
// already was. A spring starts from the current position and velocity, so an
// interrupted gesture continues instead of restarting. Three springs cover
// everyday motion; [bouncy] is reserved for the moments barter is about — a
// match found, an offer accepted, a deal closed. Anywhere else, bounce reads
// as noise.

/// A spring plus the time it needs to settle, so it can also drive the
/// ordinary implicit animations (`AnimatedContainer`, `AnimatedSwitcher`…)
/// that take a curve and a duration.
@immutable
class MotionSpec {
  const MotionSpec(this.spring, this.duration);

  final SpringDescription spring;

  /// Long enough for [spring] to be within ~1% of its target.
  final Duration duration;

  /// The spring as a 0→1 curve over [duration].
  Curve get curve => SpringCurve(spring, duration);

  /// Zero under reduce-motion: the change still happens, it just does not
  /// travel.
  Duration durationOf(BuildContext context) =>
      shouldReduceMotion(context) ? Duration.zero : duration;
}

abstract final class Motion {
  /// Small, functional: toggles, chips, a heart filling in.
  static const fast = MotionSpec(
    SpringDescription(mass: 1, stiffness: 900, damping: 60),
    Duration(milliseconds: 220),
  );

  /// The default for anything that moves across the screen.
  static const standard = MotionSpec(
    SpringDescription(mass: 1, stiffness: 380, damping: 39),
    Duration(milliseconds: 340),
  );

  /// Large surfaces: sheets, page-sized containers, the card → detail open.
  static const slow = MotionSpec(
    SpringDescription(mass: 1, stiffness: 170, damping: 26),
    Duration(milliseconds: 520),
  );

  /// Only for the swap moments (match, accepted offer, completed deal).
  static const bouncy = MotionSpec(
    SpringDescription(mass: 1, stiffness: 260, damping: 18),
    Duration(milliseconds: 700),
  );

  /// Delay between items when a list arrives, so it reads top to bottom.
  static const stagger = Duration(milliseconds: 40);
}

/// A [SpringDescription] sampled as a [Curve] over a fixed [duration].
///
/// Ends exactly at 1.0 so implicit animations land on their target even if
/// the spring would still be a hair short.
class SpringCurve extends Curve {
  const SpringCurve(this.spring, this.duration);

  final SpringDescription spring;
  final Duration duration;

  @override
  double transformInternal(double t) {
    if (t >= 1) return 1;
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    return SpringSimulation(spring, 0, 1, 0).x(t * seconds);
  }
}
