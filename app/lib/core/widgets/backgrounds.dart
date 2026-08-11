import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/girih.dart';
import 'common.dart';

/// The app's wallpaper: a soft two-colour glow with the tile lattice over it.
///
/// Green bleeds in from one corner, blue from the other — the same give-to-take
/// idea the splash states outright, said quietly enough to read behind text.
/// Over that sits [GirihField], the eight-point star lattice of Samarkand
/// tilework, faded out toward the bottom so it never reaches the content.
///
/// Both halves are drawn, not downloaded: no asset, no blur pass per frame, and
/// both re-tint themselves for the dark theme.
///
/// Reserved for the screens with no pictures of their own — the intro, sign-in
/// and profile setup. A feed of photographs needs a plain page underneath, not
/// a second thing competing for attention.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.pattern = true,
  });

  final Widget child;

  /// Scales both blooms. Below 1 for screens that already have colour of their
  /// own; the default is tuned to sit under body text without tinting it.
  final double intensity;

  /// The tile lattice. Off for screens where even a whisper of ornament would
  /// crowd the content.
  final bool pattern;

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
        // Wider than the viewport on purpose. Sized to the viewport, the two
        // blooms only tinted the corners and the middle of the page — where
        // the reading happens — stayed flat cream, which made the wallpaper
        // invisible exactly where it was supposed to be felt.
        final diameter = span * 1.25;

        return DecoratedBox(
          decoration: BoxDecoration(color: p.canvas),
          child: Stack(
            children: [
              Positioned(
                top: -diameter * 0.38,
                left: -diameter * 0.30,
                child: _Bloom(
                  diameter: diameter,
                  color: p.giveVivid,
                  alpha: alpha,
                ),
              ),
              Positioned(
                bottom: -diameter * 0.44,
                right: -diameter * 0.30,
                child: _Bloom(
                  diameter: diameter,
                  color: p.takeVivid,
                  alpha: alpha * 0.85,
                ),
              ),
              if (pattern)
                // Thins as it descends rather than vanishing. At the old
                // `fade: 0.95` the lattice was gone within the first strip of
                // the page, so on every screen below the header there was no
                // wallpaper at all — only a plain cream field.
                const Positioned.fill(
                  child: GirihField(opacity: 0.07, cell: 82, fade: 0.45),
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

/// The gradient band at the top of the feed, with the lattice worked into it.
///
/// The same tilework as the wallpaper, but reversed out in white — on a strong
/// green-to-blue field a dark line would disappear, and the pattern is what
/// keeps the header from looking like every other app's gradient.
class SwapBanner extends StatelessWidget {
  const SwapBanner({
    super.key,
    required this.height,
    required this.borderRadius,
  });

  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: p.swapGradient),
          child: const GirihField(
            color: Colors.white,
            opacity: 0.14,
            cell: 64,
            strokeWidth: 1.1,
          ),
        ),
      ),
    );
  }
}
