import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart';

/// A soft two-colour glow behind a screen's content.
///
/// Green bleeds in from one corner, blue from the other — the same give-to-take
/// idea the splash states outright, said quietly enough to read behind text.
/// Drawn as radial gradients rather than a blurred image: no asset to download,
/// no blur pass per frame, and it re-tints itself for the dark theme.
///
/// Reserved for the screens with no content of their own to carry — the intro
/// and sign-in. A feed of photographs needs a plain page underneath, not a
/// second thing competing for attention.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  final Widget child;

  /// Scales both blooms. Below 1 for screens that already have colour of their
  /// own; the default is tuned to sit under body text without tinting it.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    // Dark surfaces swallow a wash that light ones would show, so the same
    // apparent softness needs more of it.
    final alpha = (p.isDark ? 0.26 : 0.16) * intensity;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Blooms scale with the viewport: a fixed radius that reads as a soft
        // corner glow on a phone becomes a hard disc on a desktop window.
        final span = math.max(constraints.maxWidth, constraints.maxHeight);
        final diameter = span * 0.95;

        return DecoratedBox(
          decoration: BoxDecoration(color: p.canvas),
          child: Stack(
            children: [
              Positioned(
                top: -diameter * 0.42,
                left: -diameter * 0.34,
                child: _Bloom(
                  diameter: diameter,
                  color: p.giveVivid,
                  alpha: alpha,
                ),
              ),
              Positioned(
                bottom: -diameter * 0.5,
                right: -diameter * 0.38,
                child: _Bloom(
                  diameter: diameter,
                  color: p.takeVivid,
                  alpha: alpha * 0.85,
                ),
              ),
              Positioned.fill(child: child),
            ],
          ),
        );
      },
    );
  }
}

/// One radial wash. The stops fall away early so the edge never draws a ring —
/// a linear falloff leaves a visible disc boundary at these sizes.
class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.diameter,
    required this.color,
    required this.alpha,
  });

  final double diameter;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.55),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      ),
    );
  }
}
